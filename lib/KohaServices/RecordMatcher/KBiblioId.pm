package KohaServices::RecordMatcher::KBiblioId;

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

    my $context = new C4::Context;
    my $dbh = $context->dbh;

    my $isbnjoin = '';
    my $branchjoin = '';

    my $where = '0';
    my $ok = 0;
    my $bibid = defined $env->{bibid} ? $env->{bibid} : $env->{libris_bibid};
    my $isbn = $env->{isbn};
    my $l99 = $env->{libris_99};
    my $issn = $env->{issn};
    my $branchcode = $env->{branchcode};

    if (!(defined $bibid || defined $isbn || defined $l99 || defined $issn)) {
	return (0, 'No search parameter!');
    }

    my @binds = ();
    
    if (defined $bibid) {
	$where .= " OR marc003 = 'SELIBR'";
	$where .= ' AND marc001 = ?';
	push @binds, $bibid;
    } elsif (defined $l99) {
	$where .= " OR marc003 = 'LIBRIS'";
	$where .= ' AND marc001 = ?';
	push @binds, $l99;
    }
    if (defined $isbn) {
	$isbnjoin = 'JOIN k_all_isbns USING(biblionumber)';
	$where .= ' OR k_all_isbns.isbn = normalize_isbn(?)';
	push @binds, $isbn;
    }

    if (defined $issn) {
	$where .= ' OR issn = ?';
	push @binds, $issn;
    }

    if (defined $branchcode) {
	my $first = 1;
	my $branchcodes = '';
	$branchjoin = 'JOIN items USING(biblionumber)';
	for my $b (split ',', $branchcode) {
	    if ($first) {
		$first = 0;
	    } else {
		$branchcodes .= ' OR ';
	    }
	    $branchcodes .= 'items.holdingbranch = ?';
	    push @binds, $b;
	}

	$where .= " AND ($branchcodes)";
    }

    my $q = <<"EOF";
SELECT DISTINCT biblionumber, biblioitems.biblioitemnumber FROM
    k_biblio_identification
    JOIN biblio USING (biblionumber)
    JOIN biblioitems USING(biblionumber)
    $isbnjoin
    $branchjoin
WHERE
    $where
LIMIT 1;
EOF

    my $sth = $dbh->prepare($q);
    my $rv = $sth->execute(@binds);

    if (!$rv) {
	return (0, 'Database query failed!');
    }

    my $res = $sth->fetchrow_hashref();

    if (!defined $res) {
	return (1, {});
    }

    return (1, $res);
}

sub parameters {
    return ['bibid', 'isbn', 'issn', 'libris_bibid', 'libris_isbn', 'libris_issn', 'libris_99', 'branchcode'];
}


1;
