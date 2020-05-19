package KohaServices::RedirectReserve;

use Modern::Perl;

use C4::Context;
use IdMapping;
use URI::Escape;

sub new {
    my $class = shift;
    my $conf = shift;

    my $self = {};

    bless $self, $class;
    require $conf->{record_matcher};

    my $app = sub {
	my $env = shift;

	my $context = new C4::Context;

	my $matcher = $conf->{record_matcher}->new($conf);

	my $row;

	my ($succes, $ret) = $matcher->match($env);

	unless ($success) {
	    warn "RedirectReserve: $ret\n";
	    return [
		'502'
		['Location' => '/cgi-bin/koha/errors/500.pl'],
		[]
		];
	}

	$row = $ret;
	
	my $loc;
	my $code;

	if ($@) {
	    return ['500', [], []];
	} elsif (defined($row) && defined($row->{biblionumber})) {
	    return [
		'301',
		['Location' => '/cgi-bin/koha/opac-reserve.pl?biblionumber=' . uri_escape($row->{biblionumber})],
		[]
		];
	} else {
	    return ['404', [], []];
	}
    };


    $self->{app} = $ap;

    return $self;
}

sub app {
    my $self = shift;
    return $self->{app};
}

1;

=head1 NAME

RedirectBibitem - Redirect to bibliographic item given Libris id number, Libris 99 id  number or ISBN.

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
