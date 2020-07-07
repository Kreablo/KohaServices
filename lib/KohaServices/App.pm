package KohaServices::App;

our $VERSION = '1.3';

use URI::Query;

sub get_parameters {
    my $self = shift;
    my $env = shift;
    
    my %qq = URI::Query->new($env->{QUERY_STRING})->hash();

    my $params = {};

    for my $param (@{$self->parameters()}) {
	if (defined($qq{$param})) {
	    $params->{$param} = $qq{$param};
	}
    }

    return $params;
}

sub parameters {
    my $self = shift;

    return $self->{matcher}->parameters;
}

1;
