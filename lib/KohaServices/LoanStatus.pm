package KohaServices::LoanStatus;

use Modern::Perl;

use C4::Context;
use Data::Dumper;
use utf8;
use parent 'KohaServices::App';
use strict;

sub _fail {
    my $msg = shift;
    warn "LoanStatus: $msg";
    return ['502', [], [ ] ];
}

sub new {
    my $class = shift;
    my $conf = shift;

    eval "require $conf->{output_format};" .
         "require $conf->{record_matcher};";

    if ($@) {
        die $@;
    }
    
    my $context = new C4::Context;
    
    my $out = $conf->{output_format}->new($conf);
    my $matcher = $conf->{record_matcher}->new($conf);

    my $self = {
        matcher => $matcher,
	output => $out
    };
    bless $self, "$class";

    my $app = sub {
        my $env = shift;

	my $params = $self->get_parameters($env);
        my ($success, $res) = $matcher->match($params);

        unless ($success) {
            return _fail($res);
        }

        my $row = $res;

        unless (defined($row) && defined($row->{biblionumber})) {
            return ['404', [], [] ];
        }

        my $biblionumber = $row->{biblionumber};
        my $branchcode = $params->{branchcode};
	my $where = '1';
	my @binds = ();
	if (defined $branchcode) {
	    my $first = 1;
	    my $branchcodes = '';
	    for my $b (split ',', $branchcode) {
		if ($first) {
		    $first = 0;
		} else {
		    $branchcodes .= ' OR ';
		}
		$branchcodes .= 'items.holdingbranch = ?';
		push @binds, $b;
	    }
	    $where .= " AND ($branchcodes)";
	}

        my $q = <<EOF;
SELECT DISTINCT items.itemnumber,
                items.biblionumber,
                itemcallnumber,
                items.holdingbranch,
	        items.barcode,
                items.itype AS itemtype,
                itemtypes.description AS itemtype_description,
                branches.branchname AS branchname,
                ccode,
                ccode_values.lib_opac       AS ccode_lib_opac,
                ccode_values.lib            AS ccode_lib,
                location,
                loc_values.lib_opac         AS loc_lib_opac,
                loc_values.lib              AS loc_lib,
                items.notforloan,
                notloan_values.lib_opac     AS notloan_lib_opac,
                notloan_values.lib          AS notloan_lib,
                damaged,
                damaged_values.lib_opac     AS damaged_lib_opac,
                damaged_values.lib          AS damaged_lib,
                itemlost,
                lost_values.lib_opac        AS lost_lib_opac,
                lost_values.lib             AS lost_lib,
                restricted,
                restricted_values.lib_opac        AS restricted_lib_opac,
                restricted_values.lib             AS restricted_lib,
                itemlost_on,
                issues.date_due,
                                (SELECT COUNT(itemnumber) FROM hold_fill_targets WHERE hold_fill_targets.itemnumber = items.itemnumber) +
                (SELECT COUNT(reserve_id) FROM reserves          WHERE reserves.itemnumber          = items.itemnumber) +
                                (SELECT COUNT(itemnumber) FROM tmp_holdsqueue    WHERE tmp_holdsqueue.itemnumber    = items.itemnumber) AS n_reservations
FROM items
     JOIN branches ON branchcode = holdingbranch
     LEFT OUTER JOIN authorised_values AS ccode_values   ON ccode_values.authorised_value=ccode        AND ccode_values.category   = 'CCODE'
     LEFT OUTER JOIN authorised_values AS loc_values     ON loc_values.authorised_value=location       AND loc_values.category     = 'LOC'
         LEFT OUTER JOIN authorised_values AS notloan_values ON notloan_values.authorised_value=items.notforloan AND notloan_values.category = 'NOT_LOAN'
         LEFT OUTER JOIN authorised_values AS damaged_values ON damaged_values.authorised_value=damaged    AND damaged_values.category = 'DAMAGED'
         LEFT OUTER JOIN authorised_values AS lost_values    ON lost_values.authorised_value=itemlost      AND lost_values.category    = 'LOST'
         LEFT OUTER JOIN authorised_values AS restricted_values  ON restricted_values.authorised_value=restricted      AND restricted_values.category    = 'RESTRICTED'
     LEFT OUTER JOIN issues     ON items.itemnumber=issues.itemnumber
     LEFT OUTER JOIN reserves   ON items.itemnumber=reserves.itemnumber
     LEFT OUTER JOIN itemtypes ON items.itype = itemtypes.itemtype
WHERE $where AND items.biblionumber = ?;
EOF

        my $sth = $context->dbh->prepare($q);

	push @binds, $biblionumber;
        my $rv = $sth->execute( @binds );

        return _fail( 'Query failed.' ) unless $rv;

	$out->reset( $params );

        while (my $row = $sth->fetchrow_hashref) {
            $out->add_row($row);
        }

        return  [
          '200',
          [ 'Content-Type' => $out->content_type ],
          [ $out->output ], # or IO::Handle-like object
        ];
    };

    $self->{app} = $app;
    return $self;
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
