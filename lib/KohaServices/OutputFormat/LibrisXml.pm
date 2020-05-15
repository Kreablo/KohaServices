
package KohaServices::OutputFormat::LibrisXml;

use Modern::Perl;
use XML::DOM;

use parent 'KohaServices::OutputFormat';

sub new {
    my $class = shift;

    my $doc = new XML::DOM::Document();

    $doc->setXMLDecl( $doc->createXMLDecl( "1.0", "iso-8859-1", 1 ) );
    my $item_info = $doc->createElement( 'Item_Information' );
    $item_info->setAttribute( 'xmlns:xsi', 'http://www.w3.org/2001/XMLSchema-instance' );
    $item_info->setAttribute( 'xsi:noNamespaceSchemaLocation', 'http://appl.libris.kb.se/LIBRISItem.xsd' );
    $doc->appendChild( $item_info );

    my $self = {
	doc => $doc,
	item_info => $item_info
    };

    bless $self, $class;

    return $self;
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

    my $doc = $self->{doc};

    my $item = $doc->createElement( 'Item' );
    

    $self->add($item, 'Item_No', $count++ );
    $self->add($item, 'Item_CallNo', $row->{itemcallnumber} );
    $self->add($item, 'Location', $self->authval($row, 'loc') );
    $self->add($item, 'UniqueItemId', $row->{itemnumber} );

    my ($available, $s, $sdd, $sd) = $self->status($row, $reserved);

    $self->add($item, 'Status', $s );
    $self->add($item, 'Status_Date_Description', $sdd );
    $self->add($item, 'Status_Date', $sd );

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
