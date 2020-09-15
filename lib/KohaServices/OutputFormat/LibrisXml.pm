
package KohaServices::OutputFormat::LibrisXml;

use Modern::Perl;
use XML::DOM;

use parent 'KohaServices::OutputFormat';
use utf8;

sub new {
    my $class = shift;

    my $self = {
    };

    bless $self, $class;

    $self->reset();

    return $self;
}

sub reset {
    my $self = shift;
    my $params = shift;

    my $doc = new XML::DOM::Document();

    $doc->setXMLDecl( $doc->createXMLDecl( "1.0", "iso-8859-1", 1 ) );
    my $item_info = $doc->createElement( 'Item_Information' );
    $item_info->setAttribute( 'xmlns:xsi', 'http://www.w3.org/2001/XMLSchema-instance' );
    $item_info->setAttribute( 'xsi:noNamespaceSchemaLocation', 'http://appl.libris.kb.se/LIBRISItem.xsd' );
    $doc->appendChild( $item_info );


    $self->{doc} = $doc;
    $self->{item_info} = $item_info;
    $self->{count} = 1;

    $self->SUPER::reset( $params );
}

sub add {
    my ($self, $item, $tag, $content) = @_;
    my $element = $self->{doc}->createElement( $tag );
    my $text = $self->{doc}->createTextNode( $content );
    $element->appendChild($text);
    $item->appendChild( $element );
    return $item;
};

sub add_row {
    my ($self, $row, $count) = @_;

    my $reserved = $row->{n_reservations} > 0 ? 'Reserverad med ' . $row->{n_reservations} . ' på kö.' : '';

    my $doc = $self->{doc};

    my $item = $doc->createElement( 'Item' );
    
    $self->add($item, 'Item_No', $self->{count}++ );
    $self->add($item, 'Call_No', $row->{itemcallnumber} );
    my $b = $row->{branchname} // '';
    my $l = $self->authval($row, 'loc') // '';
    $self->add($item, 'Location',  $b . ($b ne '' && $l ne '' ? ', ' : '') . $l );
    $self->add($item, 'UniqueItemId', $row->{itemnumber} );

    my ($available, $s, $sdd, $sd) = $self->status($row, $reserved);

    $self->add($item, 'Status', $s );
    $self->add($item, 'Status_Date_Description', $sdd );
    $self->add($item, 'Status_Date', $sd );

    my ($policy, $p) = $self->policy($row);
    if ($policy) {
	$self->add($item, 'Loan_Policy', $p);
    } else {
	$self->add($item, 'Loan_Policy', 'Lånas ut');
    }

    $self->{item_info}->appendChild( $item );
}


sub content_type {
    return 'application/xml';
}

sub output {
    my $self = shift;

    return $self->{doc}->toString()
}

1;
