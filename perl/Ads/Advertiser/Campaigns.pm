package Ads::Advertiser::Campaigns;

#
#  campagins page of advertiser area
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
	get_block_params("adCampaigns", $req);

	my $sql;
	my $st;

	my $advertiserId = get_session("advertiserId");





	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/advertiser/campaigns.html", "main", $options);
	$Tpl->setvar("params", get_params());


#$sMessage = debug_params();

	$Tpl->setvar("sMessage", $sMessage);


	$Tpl->setvar("advertiserId", $advertiserId);


	if ($advertiserId > 0)
	{
		# parse the grid of campaigns
		grid($options, $db, $Tpl, "campaigns", 
			"SELECT c.campaignId, c.name, ca.title as category, t.title as type, d.domain as domain," .
				"c.price, c.urlActual, s.title as status, c.account, c.registered, c.updated" .
				" FROM (((campaigns as c LEFT JOIN cam_types as t ON c.typeId=t.typeId)" .
				" LEFT JOIN categories as ca ON c.categoryId=ca.categoryId)" .
				" LEFT JOIN domains as d ON c.domainId=d.domainId)" .
				" LEFT JOIN cam_statuses as s ON c.statusId=s.statusId WHERE advertiserId=" . to_sql($db, $advertiserId, "Number"),
			"SELECT count(*) as cnt FROM campaigns WHERE advertiserId=" . to_sql($db, $advertiserId, "Number"),
			{
				"campaignId" => ["campaignId", undef],
				"name" => ["name", undef],
				"category" => ["category", undef],
				"type" => ["type", undef],
				"domain" => ["domain", undef],
				"price" => ["price", undef],
				"urlActual" => ["urlActual", undef],
				"status" => ["status", undef],
				"account" => ["account", undef],
				"registered" => ["registered", undef],
				"updated" => ["updated", undef],
				"link" => ["link", "advertiser?p=campaign&campaignId="]
			},
			"advertiser",
			"campaignId");
	}


	HeaderFooter($Tpl);

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");

	$r->send_http_header('text/html');
	print $main_block;

    return OK;
}

1;
