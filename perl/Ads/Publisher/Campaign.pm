package Ads::Publisher::Campaign;

#
# Campaign page of Publisher area
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

	my $sql = "";
	my $st = undef;

	get_block_params("puCampaign", $req);


	my $publisherId = get_session("publisherId");
	my $campaignId = get_param("campaignId", 0);

	# check that campaign of current publisher
	if ($campaignId == 0)
	{
		$r->header_out(Location => 'publisher?p=campaigns');
		return REDIRECT;
	}

	my $statusId = DLookUp($db, "SELECT statusId FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));
	if ($statusId != 1 && $statusId != 3)
	{
		$r->header_out(Location => 'publisher?p=campaigns');
		return REDIRECT;
	}


	my %fields = (
		name =>			{ title=>"Name", 						value=>"",	min=>2,	max=>64 },
		categoryId =>	{ title=>"Category",	type=>"int",	value=>"",	min=>5,	max=>32,	nocheck=>1 },
		typeId =>		{ title=>"Type",		type=>"int",	value=>0,	min=>0,	max=>2,		nocheck=>1 },
		domainId =>		{ title=>"Domain",		type=>"int",	value=>0,	min=>0,	max=>2,		nocheck=>1, nohttp=>1 },
		pricePub =>		{ title=>"Price",		type=>"float",	value=>0.0,	min=>0.0		, nohttp=>1,noupdate=>1,noinsert=>1,nocheck=>1	 },
		pricePubCPM =>	{ title=>"Price CPM",	type=>"plain",	value=>0.0,	nohttp=>1, nocheck=>1, nohttp=>1	 },
		registered =>	{ title=>"Registered",	type=>"plain",	value=>"",						noupdate=>1, nohttp=>1, nocheck=>1 },
		updated =>		{ title=>"Updated",		type=>"plain",	value=>"",						nohttp=>1, nocheck=>1 },
		suppFile =>		{ title=>"supFile",		type=>"plain",	value=>"",						noupdate=>1, noinsert=>1, nohttp=>1, nocheck=>1 }
	);
#		urlActual =>	{ title=>"Url",							value=>"",	min=>2,	max=>128, nohttp=>1,noupdate=>1,noinsert=>1,nocheck=>1 },


	# get values from db fro existed record
	get_db($db, \%fields, "FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));

	my $priceSpec = DLookUp($db, "SELECT price FROM pub_cams WHERE publisherId=" . to_sql($db, $publisherId, "Number") . " AND campaignId=" . to_sql($db, $campaignId, "Number"));
	if ($priceSpec ne "")
	{
		$fields{pricePub}->{value} = $priceSpec;
		$fields{pricePubCPM}->{value} = DLookUp($db, "SELECT priceCPM FROM pub_cams WHERE publisherId=" . to_sql($db, $publisherId, "Number") . " AND campaignId=" . to_sql($db, $campaignId, "Number"));
	}

	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/publisher/campaign.html", "main", $options);
	$Tpl->setvar("params", get_params());



	if ($campaignId > 0)
	{
		# parse the grid of creatives
		grid($options, $db, $Tpl, "creatives", 
			"SELECT c.creativeId, t.title as type," .
				"s.title as status, c.registered, c.updated" .
				" FROM (creatives as c LEFT JOIN cre_types as t ON c.typeId=t.typeId)" .
				" LEFT JOIN cre_statuses as s ON c.statusId=s.statusId" .
				" WHERE c.statusId IN (1,3) AND campaignId=" . to_sql($db, $campaignId, "Number"),
			"SELECT count(*) as cnt FROM creatives WHERE statusId IN (1,3) AND campaignId=" . to_sql($db, $campaignId, "Number"),
			{
				"creativeId" => ["creativeId", undef],
				"type" => ["type", undef],
				"registered" => ["registered", undef],
				"updated" => ["updated", undef],
				"link" => ["link", "publisher?p=creative&creativeId="]
				
			},
			"publisher",
			"creativeId");
	}


#$sMessage = debug_params();

	$Tpl->setvar("sMessage", $sMessage);


	$Tpl->setvar("campaignId", $campaignId);
	$Tpl->setvar("publisherId", $publisherId);

	parse_values($Tpl, \%fields);

	if ($fields{suppFile}{value})
	{
		$Tpl->parse("bSupp");
	} else {
		$Tpl->setvar("suppFile", "No file");
	}

	$Tpl->setvar("type", DLookUp($db, "SELECT title FROM cam_types WHERE typeId=" . to_sql($db, $fields{typeId}{value}, "Number")));
	my $domainId = $fields{domainId}{value};
	if ($domainId == 0)
	{
		$domainId = 1;
	}
	$Tpl->setvar("domain", DLookUp($db, "SELECT domain FROM domains WHERE domainId=" . to_sql($db, $domainId, "Number")));
	$Tpl->setvar("category", DLookUp($db, "SELECT title FROM categories WHERE categoryId=" . to_sql($db, $fields{categoryId}{value}, "Number")));

	#if ($fields{typeId}{value} == 0 || $fields{typeId}{value} == 1)
	#{
	#	$Tpl->parse("bClick");
	#}


	HeaderFooter($Tpl);

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");

	$r->send_http_header('text/html');
	print $main_block;

    return OK;
}

1;
