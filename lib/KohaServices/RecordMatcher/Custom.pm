package KohaServices::RecordMatcher::Custom;


sub new {
    my ($class, $conf) = @_;

    my $self = {};
    
    bless $self, $class;

    return $self;
}


sub match {
    my ($self, $env) = shift;

    my $context = new C4::Context;

    my $idmapping = new IdMapping( { context => $context });

    my $row;

    eval {
	$row = $idmapping->get_biblioitem( 'libris_bibid' => $env->{'libris_bibid'},
					   'libris_99'      => $env->{'libris_99'},
					   'isbn'           => $env->{'isbn'},
					   'issn'           => $env->{'issn'} );
    };

    if ($@) {
	return (0, $@);
    }

    return (1, $row);
}

sub parameters {
    return ['libris_bibid', 'libris_99', 'isbn', 'issn'];
}
    

1;
