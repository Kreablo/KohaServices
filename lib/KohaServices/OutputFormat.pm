package KohaServices::OutputFormat;

use Koha::Items;
use Koha::IssuingRules;
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

sub policy {
    my ($self, $row) = @_;

    my $notloan = $self->authval($row, 'notloan');

    if ($row->{notforloan} && defined($notloan)) {
	return (1, $notloan);
    }

    my $restricted = $self->authval($row, 'restricted');
    if ($row->{restricted} && defined($restricted)) {
	return (1, $restricted);
    }

    my $item = Koha::Items->find( $row->{itemnumber} );

    my @rules = Koha::IssuingRules->search(
	{
	    itemtype     => { 'in' => [$item->effective_itemtype, '*'] },
	    branchcode   => { 'in' => [(split ',', $branchcode), '*'] }
	},
	{
	    order_by => {
		-desc => [ 'branchcode', 'categorycode', 'itemtype' ]
	    }
	});

    my %unique_policies = ();
    my $hasitype = 0;
    my $hasbranch = 0;
    for my $rule (@rules) {
	my $length = $rule->issuelength . ( $rule->lengthunit eq 'days' ? ' dagar' : ' timmar' );
	if ($rule->itemtype ne '*') {
	    $hasitype = 1;
	} elsif ($hasitype) {
	    next;
	}
	if ($rule->branchcode ne '*') {
	    $hasbranch = 1;
	} elsif ($hasbranch) {
	    next;
	}
	$unique_policies{$length} = 1;
    }

    my @policies = keys %unique_policies;
    @policies = sort @policies;
    if (@policies) {
	my $policies = $policies[0];
	if (@policies > 1) {
	    my $i = 1;
	    for (; $i < scalar(@policies) - 1; $i++) {
		$policies .= ', ' . $policies[$i];
	    }
	    $policies .= ' eller ' . $policies[$i];
	}

	return (1, $policies);
    }
    return (0, undef);
}

sub  authval {
    my $self = shift;
    my $row = shift;
    my $name = shift;

    if (defined($row->{"${name}_lib_opac"})) {
	return $row->{"${name}_lib_opac"};
    }
    return $row->{"${name}_lib"};
};

sub reset {
    my $self = shift;
}


1;
