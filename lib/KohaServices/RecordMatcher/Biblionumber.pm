package KohaServices::RecordMatcher::Biblionumber;

use Modern::Perl;

sub new {
    my $class = shift;
    my $conf = shift;

    my $self = {};

    bless $self, $class;

    return $self;
}

sub match {
    my $self = shift;
    my $env = shift;

    return (1, {
	biblionumber => $env->{biblionumber}
    });
}

sub parameters {
    return ['biblionumber'];
}

1;
