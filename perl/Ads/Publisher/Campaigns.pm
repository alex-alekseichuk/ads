package Ads::Publisher::Campaigns;

#
#  campagins page of publisher area
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



	my $cmd = $req->param("cmd");

	my $sMessage = "";
	my $db = $options->{db};
	get_block_params("puCampaigns", $req);

	my $sql;
	my $st;

	my $publisherId = get_session("publisherId");





	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/publisher/campaigns.html", "main", $options);
	$Tpl->setvar("params", get_params());


#$sMessage = debug_params();

	$Tpl->setvar("sMessage", $sMessage);


	$Tpl->setvar("publisherId", $publisherId);


	if ($publisherId > 0)
	{
		# parse the grid of campaigns
		grid($options, $db, $Tpl, "campaigns", 
			"SELECT c.campaignId, c.name, ca.title as category, t.title as type, d.domain as domain," .
				"if(pc.price is null, c.pricePub, pc.price) AS price, c.urlActual, s.title as status, c.account, c.registered, c.updated" .
				" FROM ((((campaigns as c LEFT JOIN cam_types as t ON c.typeId=t.typeId)" .
				" LEFT JOIN categories as ca ON c.categoryId=ca.categoryId)" .
				" LEFT JOIN domains as d ON c.domainId=d.domainId)" .
				" LEFT JOIN cam_statuses as s ON c.statusId=s.statusId)" .
				" LEFT JOIN pub_cams as pc ON (pc.campaignId=c.campaignId AND pc.publisherId=" . to_sql($db, $publisherId , "Number") . ")" .
				" WHERE c.statusId IN (1,3)",
			"SELECT count(*) as cnt FROM campaigns WHERE statusId IN (1,3)",
			{
				"campaignId" => ["campaignId", undef],
				"name" => ["name", undef],
				"category" => ["category", undef],
				"type" => ["type", undef],
				"price" => ["price", undef],
				"registered" => ["registered", undef],
				"link" => ["link", "publisher?p=campaign&campaignId="]
			},
			"publisher",
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
