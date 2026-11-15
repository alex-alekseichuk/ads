package Ads::Admin::PubCamPrice;

#
# Special price for specified publisher and campaign
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

	my $sCheck = checkAdminGrants(2);
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
	get_block_params("aPubCamPrice", $req);

	my $sql = "";
	my $st = undef;


	my $publisherId = get_param("publisherId", 0);
	my $campaignId2 = get_param("campaignId2", 0);




	# delete the price
	if($campaignId2 > 0 && $publisherId > 0 && $cmd eq "delete")
	{
		$db->do("DELETE FROM pub_cams WHERE campaignId=" . to_sql($db, $campaignId2, "Number") . " AND publisherId=" . to_sql($db, $publisherId, "Number"));
		$r->header_out(Location => 'admin?p=publisher&mes=pricedeleted&' . get_params());
		return REDIRECT;
	}


	my %fields = (
		publisherId =>	{ title=>"Publisher",		type=>"int",	value=>$publisherId,	min=>0,			nocheck=>1 },
		campaignId =>	{ title=>"Campaign",		type=>"int",	value=>$campaignId2,		min=>0,			nocheck=>1 },
		price =>	{ title=>"Price",	type=>"float",	value=>0.0,	min=>0.0 },
		priceCPM =>		{ title=>"Price CPM",		type=>"plain",	value=>0.0,	nohttp=>1, nocheck=>1	 }
	);


	my $bAlreadyExists = 0;

	# get values from http
	if ($cmd eq "create" || ($cmd eq "update" && $publisherId > 0))
	{
		get_http(\%fields);

		my $typeId = DLookUp($db, "SELECT typeId FROM campaigns WHERE campaignId=" . to_sql($db, $fields{campaignId}{value}, "Number"));
		if ($typeId == 2) # if per 1000 views type then we need to have price for one view
		{
			$fields{priceCPM}->{value} = $fields{price}->{value} / 1000;
		}

		if ($campaignId2 != $fields{campaignId}{value})
		{
			if (
				DLookUp($db, "SELECT count(*) FROM pub_cams WHERE campaignId=" . to_sql($db, $fields{campaignId}{value}, "Number") . " AND publisherId=" . to_sql($db, $publisherId, "Number"))
				> 0
			)
			{
				$cmd = "";
				$sMessage = "Special price for this campaign already exists";
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
			$r->header_out(Location => "admin?p=publisher&mes=pricecreated&" . get_params());
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
	}

	# update action
	if ($cmd eq "update" && $publisherId > 0)
	{

		$sql = "UPDATE pub_cams SET " .
			fields_to_sql($db, \%fields) .
			" WHERE campaignId=" . to_sql($db, $campaignId2, "Number") . " AND publisherId=" . to_sql($db, $publisherId, "Number");

		my $res = $db->do($sql);

		if ($res != 0)		
		{
			$r->header_out(Location => "admin?p=publisher&mes=priceupdated&" . get_params());
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
	}


	# get values from db for existed record
	if($campaignId2 > 0 && $publisherId > 0)
	{
		get_db($db, \%fields, "FROM pub_cams WHERE campaignId=" . to_sql($db, $campaignId2, "Number") . " AND publisherId=" . to_sql($db, $publisherId, "Number"));
	}


	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/admin/pubcamprice.html", "main", $options);
	$Tpl->setvar("params", get_params());

#$sMessage = debug_params();

	$Tpl->setvar("sMessage", $sMessage);


	$Tpl->setvar("campaignId2", $campaignId2);

	$Tpl->setvar("publisherId", $publisherId);

	$Tpl->setvar("pubprice_checks", html_checks(\%fields, "pubprice"));

	parse_values($Tpl, \%fields);

	$Tpl->setvar("campaignIdOptions", DSelectOptions($db, "SELECT campaignId, name FROM campaigns", $fields{campaignId}{value}));


	if ($campaignId2 > 0 && $publisherId > 0)
	{
		$Tpl->setvar("sTitle", "Price for campaign #" . $campaignId2);
		$Tpl->setvar("sCmd", "Update");
		$Tpl->setvar("cmd", "update");
		$Tpl->parse("bDelete");
    } else {
		$Tpl->setvar("sTitle", "New campaign price");
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
