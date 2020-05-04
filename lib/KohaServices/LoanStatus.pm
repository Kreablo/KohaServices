package KohaServices::LoanStatus;

@ISA         = qw(Exporter);
@EXPORT      = qw(loan_status_app);
@EXPORT_OK   = qw();

our $VERSION = '1.0';

use Modern::Perl;
use XML::DOM;

use C4::Context;
use IdMapping;
use Data::Dumper;
use utf8;

sub _fail {
    my $msg = shift;
    warn "LoanStatus: $msg";
    return ['502', [], [ ] ];
}

sub new {
    my $class = shift;
    my $conf = shift;

    require $conf->{output_format};
    require $conf->{record_matcher};
    
    my $out = $conf->{output_format}->new($conf);
    my $matcher = $conf->{record_matcher}->new($conf);

    my $app = sub {
	my $env = shift;

	my ($success, $res) = $matcher->match($env);

	unless ($success) {
	    return _fail($res);
	}

	my $row = $res;

	unless (defined($row) && defined($row->{biblionumber})) {
		return ['404', [], [] ];
	}

	my $biblionumber = $row->{biblionumber};
	
	my $q = <<'EOF';
SELECT DISTINCT items.itemnumber,
                items.biblionumber,
                itemcallnumber,
				ccode_values.lib_opac       AS ccode_lib_opac,
				ccode_values.lib            AS ccode_lib,
				loc_values.lib_opac         AS loc_lib_opac,
				loc_values.lib              AS loc_lib,
				notloan_values.lib_opac     AS notloan_lib_opac,
				notloan_values.lib          AS notloan_lib,
				damaged_values.lib_opac     AS damaged_lib_opac,
				damaged_values.lib          AS damaged_lib,
				lost_values.lib_opac        AS lost_lib_opac,
				lost_values.lib             AS lost_lib,
	            itemlost_on,
                issues.date_due,
				(SELECT COUNT(itemnumber) FROM hold_fill_targets WHERE hold_fill_targets.itemnumber = items.itemnumber) +
                (SELECT COUNT(reserve_id) FROM reserves          WHERE reserves.itemnumber          = items.itemnumber) +
				(SELECT COUNT(itemnumber) FROM tmp_holdsqueue    WHERE tmp_holdsqueue.itemnumber    = items.itemnumber) AS n_reservations
FROM items
     LEFT OUTER JOIN authorised_values AS ccode_values   ON ccode_values.authorised_value=ccode        AND ccode_values.category   = 'CCODE'
     LEFT OUTER JOIN authorised_values AS loc_values     ON loc_values.authorised_value=location       AND loc_values.category     = 'LOC'
	 LEFT OUTER JOIN authorised_values AS notloan_values ON notloan_values.authorised_value=notforloan AND notloan_values.category = 'NOT_LOAN'
	 LEFT OUTER JOIN authorised_values AS damaged_values ON damaged_values.authorised_value=damaged    AND damaged_values.category = 'DAMAGED'
	 LEFT OUTER JOIN authorised_values AS lost_values    ON lost_values.authorised_value=itemlost      AND lost_values.category    = 'LOST'
     LEFT OUTER JOIN issues     ON items.itemnumber=issues.itemnumber
     LEFT OUTER JOIN reserves   ON items.itemnumber=reserves.itemnumber
WHERE items.biblionumber = ?;
EOF

	my $sth = $context->dbh->prepare($q);
	my $rv = $sth->execute( $biblionumber );

	return _fail( 'Query failed.' ) unless $rv;

	my $count = 1;

	while (my $row = $sth->fetchrow_hashref) {
	    $out->add_row($row, $count);
	}


	return  [
          '200',
          [ 'Content-Type' => $out->content_type ],
          [ $out->output ], # or IO::Handle-like object
        ];
    };

    my $self = {
	app => $app,
	matcher => $macher
    };

    bless $self, "$class";
    return $self;
}


sub parameters {
    my $self = shift;

    return $self->{matcher}->parameters;
}

sub app {
    my $self = shift;

    return $self->{app};
}

1;

=head1 NAME

LoanStatus - Fetch information of the loan status of Koha items

=head1 SYNOPSIS


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
