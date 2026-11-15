package Ads::Advertiser::CamPayments;

#
# payments of campaigns
#

use strict;
use Apache::Constants qw(:common);
use Apache::Request ();
use Apache::Cookie ();

use Ads::Common;
use Ads::Template;
use Ads::Record;
use Ads::Grid;

use Ads::Advertiser::Common;


sub process {
    my $options = shift;

	my $r = $options->{r};
	my $req = $options->{req};

	# if advertiser is not logged in then redirect to login
	if (get_session("advertiserId") eq "")
	{
		$r->header_out(Location => 'advertiser?p=login&mes=login');
		return REDIRECT;
	}

	my $cmd = $req->param("cmd");

	my $sMessage = "";
	my $db = $options->{db};
	get_block_params("adCampaign", $req);

	my $sql;


	my $advertiserId = get_session("advertiserId");
	my $campaignId = get_param("campaignId", 0);

	# check that campaign of current advertiser
	if ($campaignId > 0)
	{
		if ($advertiserId != DLookUp($db, "SELECT advertiserId FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number")))
		{
			$r->header_out(Location => 'advertiser?p=campaigns');
			return REDIRECT;
		}
	} else {
		$r->header_out(Location => 'advertiser?p=campaigns');
		return REDIRECT;
	}


	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/advertiser/cam_payments.html", "main", $options);
	$Tpl->setvar("params", get_params());


	# parse the grid of payments
	grid($options, $db, $Tpl, "payments", 
		"SELECT amount, paid, notes FROM cam_payments WHERE campaignId=" . to_sql($db, $campaignId, "Number"),
		"SELECT count(*) as cnt FROM cam_payments WHERE campaignId=" . to_sql($db, $campaignId, "Number"),
		{
			"amount" => ["amount", undef],
			"paid" => ["paid", undef],
			"notes" => ["notes", undef]
		},
		"advertiser",
		"paid");


#$sMessage = debug_params();

	$Tpl->setvar("sMessage", $sMessage);

	$Tpl->setvar("campaignId", $campaignId);
	$Tpl->setvar("sTitle", "Campaign #" . $campaignId);

#	parse_values($Tpl, \%fields);

	$Tpl->parse("bCampaign", "false");
	


	HeaderFooter($Tpl);

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");

	$r->send_http_header('text/html');
	print $main_block;


    return OK;
}

1;
