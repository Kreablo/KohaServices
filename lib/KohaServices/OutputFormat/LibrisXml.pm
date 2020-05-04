
package KohaServices::OutputFormat::LibrisXml;

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

sub  authval {
    my $row = shift;
    my $name = shift;

    if (defined($row->{"${name}_lib_opac"})) {
	return $row->{"${name}_lib_opac"};
    }
    return $row->{"${name}_lib"};
};

sub add {
    my ($self, $item, $tag, $content) = @_;
    my $element = $self->{doc}->createElement( $tag );
    my $text = $self->{doc}->createTextNode( $content );
    $element->appendChild($text);
    $item->appendChild( $element );
    return $item;
};

sub status {
    my ($self, $row) = @_;
    if (defined($row->{'date_due'})) {
	return ("Utlånad$reserved",
		"Åter: ",
		substr($row->{'date_due'}, 0, 10));
    }
    my $notloan = authval($row, 'notloan');
    if (defined($notloan)) {
	return ($notloan, '', '');
    }
    my $lost = authval($row, 'lost');
    if (defined($lost)) {
	return ($lost, defined($row->{'itemlost_on'}) ? ('Förlorad den: ', substr($row->{'itemlost_on'}, 0, 10))  : ('', ''));
    }
    my $damaged = authval($row, 'damaged');
    if (defined($damaged)) {
	return ($damaged, '', '');
    }
    if (defined($row->{'n_reservations'}) && $row->{'n_reservations'} > 0) {
	return ($reserved, '', '');
    }
    return ('Tillgänglig', '', '');
};


sub add_row {
    my ($self, $row, $count) = @_;

    my $doc = $self->{$doc};



    my $item = $doc->createElement( 'Item' );

    

    $self->add($item, 'Item_No', $count++ );
    $self->add($item, 'Item_CallNo', $row->{itemcallnumber} );
    $self->add($item, 'Location', authval($row, 'loc') );
    $self->add($item, 'UniqueItemId', $row->{itemnumber} );

    my $reserved = $row->{n_reservations} > 0 ? ' reserverad med ' . $row->{n_reservations} . ' på kö.' : '';

    my ($s, $sdd, $sd) = $self->status($row);

    $self->add($item, 'Status', $s );
    $self->add($item 'Status_Date_Description', $sdd );
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
