package KohaServices::OutputFormat;

use utf8;

sub status {
    my ($self, $row) = @_;

    my $reserved = $row->{n_reservations} > 0 ? ' reserverad med ' . $row->{n_reservations} . ' på kö.' : '';
    
    if (defined($row->{'date_due'})) {
	return (0, "Utlånad$reserved",
		"Åter: ",
		substr($row->{'date_due'}, 0, 10));
    }
    my $notloan = $self->authval($row, 'notloan');
    if (defined($notloan) && $row->{notforloan}) {
	return (0, $notloan, '', '');
    }
    my $lost = $self->authval($row, 'lost');
    if (defined($lost) && $row->{lost}) {
	return (0, $lost, defined($row->{'itemlost_on'}) ? ('Förlorad den: ', substr($row->{'itemlost_on'}, 0, 10))  : ('', ''));
    }
    my $damaged = $self->authval($row, 'damaged');
    if (defined($damaged) && $row->{damaged}) {
	return (0, $damaged, '', '');
    }
    if (defined($row->{'n_reservations'}) && $row->{'n_reservations'} > 0) {
	return (0, $reserved, '', '');
    }
    return (1, 'Tillgänglig', '', '');
};

sub  authval {
    my $self = shift;
    my $row = shift;
    my $name = shift;

    if (defined($row->{"${name}_lib_opac"})) {
	return $row->{"${name}_lib_opac"};
    }
    return $row->{"${name}_lib"};
};

1;
