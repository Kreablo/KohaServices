package KohaServices::App;

our $VERSION = '1.11';

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

    my $mp = $self->{matcher}->parameters;

    my @parameters = @$mp;

    if (defined $self->{output}) {
        my $op = $self->{output}->parameters;
        push @parameters, @$op;
    }

    sort @parameters;
    
    my @p = ();
    my $prev;

    for my $p (@parameters) {
	if (defined $prev && $prev eq $p) {
	    next;
	}
	$prev = $p;
	push @p, $p;
    }
    

    return \@p;
}

1;
