package KohaServices::OutputFormat::SummonJson;

use parent 'KohaServices::OutputFormat';

use JSON;
use Modern::Perl;
use Data::Dumper;

sub new {
    my $class = shift;

    my $self = {};

    bless $self, $class;

    $self->{res} = {
	data => []
    };

    return $self;
}

sub add_row {
    my ($self, $row, $count) = @_;
    my $reserved = $row->{n_reservations} > 0 ? 'Reserverad med ' . $row->{n_reservations} . ' på kö.' : '';
    my ($available, $s, $sdd, $sd) = $self->status($row, $reserved);

    my $classname = $available ? "available" : "unavailable";

    my $res = {
	id                   => $row->{itemnumber},
	availability         => $available ? JSON::true : JSON::false,
	availability_message => '<span class="' . $classname . '">' . $s . '</span>',
	callnumber           => $row->{itemcallnumber},
	location             => $row->{branchname} . ' ' . $self->authval($row, 'loc'),
	locationList         => JSON::false,
	reserve              => $row->{n_reservations} > 0 ? JSON::true : JSON::false,
	reserve_message      => $reserved
    };

    push @{$self->{res}->{data}}, $res;
}

sub content_type {
    return 'application/json';
}

sub output {
    my $self = shift;

    return JSON->new->utf8->encode($self->{res});
}

1;
