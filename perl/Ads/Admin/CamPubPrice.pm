package Ads::Admin::CamPubPrice;

#
# Special price for specified campaign and publisher
#


use strict;
use Apache::Constants qw(:common);
use Apache::Request ();
use Apache::Cookie ();
use DBI;

use Ads::Common;
use Ads::Template;
use Ads::Record;
use Ads::Grid;

use Ads::Admin::Common;


sub process {
    my $options = shift;

	my $r = $options->{r};
	my $req = $options->{req};

	my $sCheck = checkAdminGrants(1);
	if ($sCheck eq "denied")
	{
		$r->header_out(Location => 'admin?p=message&mes=denied');
		return REDIRECT;
	}
	if ($sCheck eq "login")
	{
		$r->header_out(Location => 'admin?p=login&mes=login');
		return REDIRECT;
	}

	my $cmd = $req->param("cmd");

	my $sMessage = "";
	my $db = $options->{db};
	get_block_params("aCamPubPrice", $req);

	my $sql = "";
	my $st = undef;


	# get campaignId from HTTP
	my $campaignId = get_param("campaignId", 0);

	# the campaign should be anyway
	if ($campaignId == 0)
	{
		$r->header_out(Location => 'admin?p=advertiser');
		return REDIRECT;
	}
	$g_param_values{campaignId} = $campaignId;

	my $typeId = DLookUp($db, "SELECT typeId FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));

	# get advertiser from DB by campaign
	my $advertiserId = DLookUp($db, "SELECT advertiserId FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));
	if ($advertiserId == 0)
	{
		$r->header_out(Location => 'admin?p=advertisers');
		return REDIRECT;
	}
	$g_param_values{advertiserId} = $advertiserId;



	# get pub from HTTP
	my $publisherId2 = get_param("publisherId2", 0);



	# delete the price
	if($campaignId > 0 && $publisherId2 > 0 && $cmd eq "delete")
	{
		$db->do("DELETE FROM pub_cams WHERE campaignId=" . to_sql($db, $campaignId, "Number") . " AND publisherId=" . to_sql($db, $publisherId2, "Number"));
		$r->header_out(Location => 'admin?p=campaign&mes=pricedeleted&' . get_params());
		return REDIRECT;
	}


	my %fields = (
		publisherId =>	{ title=>"Publisher",		type=>"int",	value=>$publisherId2,	min=>0,			nocheck=>1 },
		campaignId =>	{ title=>"Campaign",		type=>"int",	value=>$campaignId,		min=>0,			nocheck=>1 },
		price =>	{ title=>"Price",	type=>"float",	value=>0.0,	min=>0.0 },
		priceCPM =>		{ title=>"Price CPM",		type=>"plain",	value=>0.0,	nohttp=>1, nocheck=>1	 }
	);


	my $bAlreadyExists = 0;

	# get values from http
	if ($cmd eq "create" || ($cmd eq "update" && $campaignId > 0))
	{
		get_http(\%fields);
		if ($typeId == 2) # if per 1000 views type then we need to have price for one view
		{
			$fields{priceCPM}->{value} = $fields{price}->{value} / 1000;
		}

		if ($publisherId2 != $fields{publisherId}{value})
		{
			if (
				DLookUp($db, "SELECT count(*) FROM pub_cams WHERE campaignId=" . to_sql($db, $campaignId, "Number") . " AND publisherId=" . to_sql($db, $fields{publisherId}{value}, "Number"))
				> 0
			)
			{
				$cmd = "";
				$sMessage = "Special price for this publisher already exists";
			}
		}

	}

	# create new action
	if ($cmd eq "create")
	{

		$sql = "INSERT INTO pub_cams (" .
			sql_fields($db, \%fields) .
			") VALUES (" .
			sql_values($db, \%fields) .
			")";			

		my $res = $db->do($sql);

		if ($res != 0)		
		{
			$r->header_out(Location => "admin?p=campaign&mes=pricecreated&" . get_params());
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
	}

	# update action
	if ($cmd eq "update" && $campaignId > 0)
	{

		$sql = "UPDATE pub_cams SET " .
			fields_to_sql($db, \%fields) .
			" WHERE campaignId=" . to_sql($db, $campaignId, "Number") . " AND publisherId=" . to_sql($db, $publisherId2, "Number");

		my $res = $db->do($sql);

		if ($res != 0)		
		{
			$r->header_out(Location => "admin?p=campaign&mes=priceupdated&" . get_params());
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
	}


	# get values from db for existed record
	if($campaignId > 0 && $publisherId2 > 0)
	{
		get_db($db, \%fields, "FROM pub_cams WHERE campaignId=" . to_sql($db, $campaignId, "Number") . " AND publisherId=" . to_sql($db, $publisherId2, "Number"));
	}


	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/admin/campubprice.html", "main", $options);
	$Tpl->setvar("params", get_params());

#$sMessage = debug_params();

	$Tpl->setvar("sMessage", $sMessage);


	$Tpl->setvar("campaignId", $campaignId);
	$Tpl->setvar("advertiserId", $advertiserId);

	$Tpl->setvar("publisherId2", $publisherId2);

	$Tpl->setvar("pubprice_checks", html_checks(\%fields, "pubprice"));

	parse_values($Tpl, \%fields);

	$Tpl->setvar("publisherIdOptions", DSelectOptions($db, "SELECT publisherId, company FROM publishers", $fields{publisherId}{value}));


	if ($campaignId > 0 && $publisherId2 > 0)
	{
		$Tpl->setvar("sTitle", "Price for publisher #" . $publisherId2);
		$Tpl->setvar("sCmd", "Update");
		$Tpl->setvar("cmd", "update");
		$Tpl->parse("bDelete");
    } else {
		$Tpl->setvar("sTitle", "New Publisher price");
		$Tpl->setvar("sCmd", "Create");
		$Tpl->setvar("cmd", "create");
	}



	HeaderFooter($Tpl);

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");

	$r->send_http_header('text/html');
	print $main_block;

    return OK;
}

1;
