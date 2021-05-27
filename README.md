
Loan status and other services for Koha integration with discovery systems
==========================================================================

This module contains three plack applications for integration with real-time-availability check services.

* KohaServices::LoanStatus
* KohaServices::RedirectBibitem
* KohaSerivces::RedirectReserve

There are two configurable modules that provides the base of the
service: a record matcher and an output format. See
lib/KohaServices/RecordMatcher and lib/KohaServices/OutputFormat for available modules.

Installation
------------

    perl Makefile.PL
    make
    make test
    make install

Usage
-----

Add to plack.psgi.

	use KohaServices::RedirectBibitem;
	use KohaServices::RedirectReserve;
	use KohaServices::LoanStatus;


	my $loan_status = new KohaServices::LoanStatus({
                record_matcher => 'KohaServices::RecordMatcher::KBiblioId',
                output_format => 'KohaServices::OutputFormat::LibrisXml'
        });

	my $redirect_bibitem = new KohaServices::RedirectBibitem({
                record_matcher => 'KohaServices::RecordMatcher::KBiblioId'
        });

	my $redirect_reserve = new KohaServices::RedirectReserve({
                record_matcher => 'KohaServices::RecordMatcher::KBiblioId'
        });

    builder {

       .
       .
       .

        mount '/redirect-bibitem' => $redirect_bibitem->app;
        mount '/loan-status'      => $loan_status->app;
        mount '/redirect-reserve' => $redirect_reserve->app;
    }

Trigger for KohaServices::RecordMatcher::KBiblioId
--------------------------------------------------

The KBiblioId record matcher is based on the custom tables
k_biblio_identification and k_all_isbns which must be maintained via
database triggers on the table biblio_metadata.

Database table for KohaServices::RecordMatcher::Custom
------------------------------------------------------

WARNING: This is outdated and might not work.

Before using the table used in IdMap.pm needs to be created.

    CREATE TABLE `kreablo_idmapping` (
        `idmap` int NOT NULL AUTO_INCREMENT,
        `biblioitemnumber` int(11) NOT NULL,
        `kidm_bibid` mediumtext COLLATE utf8_unicode_ci,
        `kidm_99` mediumtext COLLATE utf8_unicode_ci,
        PRIMARY KEY (`idmap`),
        KEY `kidm_bibid` (`kidm_bibid`(255)),
        KEY `kidm_99` (`kidm_99`(255)),
       FOREIGN KEY (`biblioitemnumber`) REFERENCES `biblioitems` (`biblioitemnumber`) ON DELETE CASCADE ON UPDATE CASCADE
     );




Linking syntax for Libris

URL till lånestatus:

https://bibliotekivastmanland.se/loan-status?bibid=%BIBID%&libris_99=%ONR%&isbn=%ISBN%

Stöd för länkning till post i OPAC - URL vid stöd för bibid

https://bibliotekivastmanland.se/redirect-bibitem?bibid=%BIBID%&libris_99=%ONR%&isbn=%ISBN% 

Lopac - URL vid BibID-länkning

https://bibliotekivastmanland.se/redirect-bibitem?bibid=%BIBID%
