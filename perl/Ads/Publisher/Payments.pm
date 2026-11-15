package Ads::Publisher::Payments;

#
# payments of this publisher
#

use strict;
use Apache::Constants qw(:common);
use Apache::Request ();
use Apache::Cookie ();

use Ads::Common;
use Ads::Template;
use Ads::Record;
use Ads::Grid;

use Ads::Publisher::Common;


sub process {
    my $options = shift;

	my $r = $options->{r};
	my $req = $options->{req};

	# if publisher is not logged in then redirect to login
	if (get_session("publisherId") eq "")
	{
		$r->header_out(Location => 'publisher?p=login&mes=login');
		return REDIRECT;
	}

	my $publisherId = get_session("publisherId");


	my $cmd = $req->param("cmd");

	my $sMessage = "";
	my $db = $options->{db};

	my $sql;



	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/publisher/payments.html", "main", $options);
	$Tpl->setvar("params", get_params());


#$sMessage = debug_params();

	$Tpl->setvar("sMessage", $sMessage);



	# parse the grid of payments
	grid($options, $db, $Tpl, "payments", 
		"SELECT amount, paid, notes FROM pub_payments WHERE publisherId=" . to_sql($db, $publisherId, "Number"),
		"SELECT count(*) as cnt FROM pub_payments WHERE publisherId=" . to_sql($db, $publisherId, "Number"),
		{
			"amount" => ["amount", undef],
			"paid" => ["paid", undef],
			"notes" => ["notes", undef]
		},
		"publisher",
		"paid");


	HeaderFooter($Tpl);

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");

	$r->send_http_header('text/html');
	print $main_block;


    return OK;
}

1;
