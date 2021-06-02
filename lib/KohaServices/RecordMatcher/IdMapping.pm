package KohaServices::RecordMatcher::IdMapping;

use Modern::Perl;

sub new {
    my $class = shift;
    my $conf = shift;

    my $self = {};

    bless $self, $class;

    return $self;
}

sub _add {
    my ($w, $par, $pend_w, $pend_end, $where, $pending, $params_in, $params_out) = @_;

    if (defined($params_in->{$par}) && $params_in->{$par} ne '') {

        my $valid = 1;

        if ($par eq 'isbn' && !($params_in->{$par} =~ m/^\d{10,13}$/)) {
            $valid = 0;
        }

        if ($valid) {
            if (defined($$pending)) {
                $$where .= $$pending;
                $$pending = undef;
            }

            $$where .= $w;
            push @$params_out, $params_in->{$par};


            if (defined($pend_w)) {
                $$pending = $pend_w;
            }
        }

    }
    delete($params_in->{$par});
}

sub match {
    my ($self, $env) = @_;

    my %params = %$env;
    my %params_clone = %params;

    my $context = new C4::Context;

    my $where = '';
    my @params = ();
    my $pending;

    my $add = sub {
        my ($w, $par, $pend_w) = @_;
        _add ($w, $par, $pend_w,  \%params, \$where, \$pending, \%params, \@params);
    };

    $add->('kidm_bibid = ?', 'libris_bibid', ' OR ISNULL(kidm_bibid) AND ');
    $add->('kidm_99 = ?', 'libris_99', ' OR ISNULL(kidm_99) AND ');
    $add->("isbn LIKE CONCAT(?, '\%')", 'isbn', ' OR ISNULL(isbn) AND ');
    $add->("issn LIKE CONCAT(?, '\%')", 'issn', ' OR ISNULL(issn) AND ');

    if (+keys(%params) > 0) {
        return(0, "Unknown parameters: " . join(", ", keys %params));
    }

    if (+@params == 0) {
        return(0, "No parameters given!");
    }

    my $row = $self->do_query($where, @params);

    if (!defined($row)) {
        $row = $self->do_query_slow( %params_clone );
    }

    if (!defined($row)) {
        return (1, {});
    }

    return (1, $row);
}

sub do_query {
    my ($self, $where, @params) = @_;

    my $q = <<"EOF";
SELECT biblionumber, biblioitems.biblioitemnumber, kidm_bibid, kidm_99, isbn, issn FROM
    kreablo_idmapping JOIN biblioitems USING(biblioitemnumber) JOIN biblio USING(biblionumber)
WHERE
    $where;
EOF

    my $context = new C4::Context;
    my $sth = $context->dbh->prepare($q);
    my $rv = $sth->execute(@params);

    return undef unless $rv;

    if ($sth->rows == 0) {
        return undef;
    } else {
        if ($sth->rows > 1) {
            warn("More than one 1 line mathed.  Query: $q params: " . join(", ", @params));
        }
    }

    return $sth->fetchrow_hashref;
}

sub do_query_slow {
    my ($self, %params) = @_;

    my $libris_bibid = $params{libris_bibid};
    my $libris_99    = $params{libris_99};

    my $where = '';
    my @params = ();
    my $pending;

    my $add = sub {
        my ($w, $par, $pend_w) = @_;
        _add ($w, $par, $pend_w, \%params, \$where, \$pending, \%params, \@params);
    };

    $add->("isbn LIKE CONCAT(?, '%')", 'isbn', ' OR ISNULL(isbn) AND ');
    $add->('issn = ?', 'issn', ' OR ISNULL(issn) AND ');
    $add->("(ExtractValue(metadata, '//controlfield[\@tag=\"003\"]') REGEXP 'libr') AND ExtractValue(metadata, '//controlfield[\@tag=\"001\"]') = ?", 'libris_bibid', ' OR ');
    $add->("(ExtractValue(metadata, '//controlfield[\@tag=\"003\"]') REGEXP 'libr') AND ExtractValue(metadata, '//controlfield[\@tag=\"001\"]') = ?", 'libris_99', ' OR ');

    my $q = <<"EOF";
SELECT biblionumber, biblioitems.biblioitemnumber, isbn, issn, ExtractValue(metadata, '//controlfield[\@tag=\"001\"]') as controlnumber, ExtractValue(metadata, '//controlfield[\@tag=\"003\"]') as idtype
FROM
  biblioitems
  JOIN biblio USING (biblionumber)
  JOIN biblio_metadata USING(biblionumber)
WHERE
  biblio_metadata.format = 'marcxml' AND
  ($where);
EOF


    my $context = new C4::Context;
    my $sth = $context->dbh->prepare($q);
    my $rv = $sth->execute( @params );

    return undef unless $rv;

    if ($sth->rows == 0) {

        return undef;
    } else {
        if ($sth->rows > 1) {
            carp("More than one 1 line mathed.  Query: $q params: " . join(", ", @params));
        }
    }

    my $row = $sth->fetchrow_hashref;

    my @cols = ();
    my @vals = ();

    my $result = {};

    my $ins = sub {
        my ($col, $val) = @_;
        if (defined($val) && $val ne '') {
            push @cols, $col;
            push @vals, $val;
            $result->{$col} = $val;
        }
    };

    my $skip = 0;

    if (defined($libris_bibid) && $libris_bibid ne '' && $libris_bibid eq $row->{controlnumber}) {
        $ins->( 'kidm_bibid', $row->{controlnumber} );
    } elsif (defined($libris_99) && $libris_99 ne '' && $libris_99 eq $row->{controlnumber}) {
        $ins->( 'kidm_99', $row->{controlnumber});
    } else {
        $skip = 1;
    }
    $ins->( 'biblioitemnumber', $row->{biblioitemnumber} );
    $result->{biblionumber} = $row->{biblionumber};

    unless ($skip) {
        my $insert = "INSERT INTO `kreablo_idmapping` (";
        $insert .= join(", ", @cols);
        $insert .= ") VALUES (";
        my @foo = map {'?'} @vals;
        $insert .= join(", ", @foo);
        $insert .=  ");";
        $sth = $context->dbh->prepare($insert);
        $rv = $sth->execute( @vals );
                
        if (!$rv) {
            warn "Failed to insert values!";
        }


    }

    return $result;
}

sub create_table {
    my $self = shift;

    my $context = new C4::Context;

    $context->dbh->do(<<"EOF");
CREATE TABLE `kreablo_idmapping` (
    `idmap` int NOT NULL AUTO_INCREMENT,
    `biblioitemnumber` int(11) NOT NULL,
    `kidm_bibid` mediumtext COLLATE utf8_unicode_ci,
    `kidm_99` mediumtext COLLATE utf8_unicode_ci DEFAULT NULL,
    PRIMARY KEY (`idmap`),
    KEY `kidm_bibid` (`kidm_bibid`(255)),
    KEY `kidm_99` (`kidm_99`(255)),
   FOREIGN KEY (`biblioitemnumber`) REFERENCES `biblioitems` (`biblioitemnumber`) ON DELETE CASCADE ON UPDATE CASCADE
   );
EOF
}

sub parameters {
    return ['libris_bibid', 'isbn', 'issn', 'libris_99'];
}

1;

=head1 NAME

IdMapping - Maintain a table for mapping Libris identifiers to Koha identifiers.

=head1 SYNOPSIS

my $context = new C4::Context;
my $idmapping = new IdMapping({ context => $context });

my $row = $idmapping->get_biblioitem( 'libris_bibid'   => $env->{'libris_bibid'},
                                      'libris_99'      => $env->{'libris_99'},
				      'isbn'           => $env->{'isbn'},
				      'issn'           => $env->{'issn'} );


=head1 AUTHOR

Andreas Jonsson, Kreablo AB  <andreas.jonsson@kreablo.se>

=head1 LICENCE

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
