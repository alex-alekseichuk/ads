package Ads::Admin::Advertiser;

#
# advertiser page of admin area
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
	get_block_params("aAdvertiser", $req);

	my $sql;
	my $st;

	my $advertiserId = get_param("advertiserId", 0);


	# delete advertiser
	if($advertiserId > 0 && $cmd eq "delete")
	{
		$sql = "SELECT campaignId FROM campaigns WHERE advertiserId=" . to_sql($db, $advertiserId, "Number");
		$st = $db->prepare($sql);
		$st->execute;
		my $campaigns = $st->fetchall_arrayref;
		$st->finish;
		
		foreach my $row (@$campaigns)
		{
			my ($campaignId) = @$row;

			$sql = "SELECT i.creativeId, i.name FROM cre_imgs as i join creatives as c ON c.creativeId=i.creativeId WHERE campaignId=" . to_sql($db, $campaignId, "Number");
			$st = $db->prepare($sql);
			$st->execute;
			while (my $row = $st->fetchrow_hashref() )
			{
				unlink $options{ImgDir} . "/" . $row->{creativeId} . "_" . $row->{name};
			}
			$st->finish;

			my $creativeId = 0;
			$sql = "SELECT creativeId FROM creatives WHERE campaignId=" . to_sql($db, $campaignId, "Number");
			$st = $db->prepare($sql);
			$st->execute;
			while (($creativeId) = $st->fetchrow_array)
			{
				$db->do("DELETE FROM cre_imgs WHERE creativeId=" . to_sql($db, $creativeId, "Number"));
			}
			$st->finish;

			$db->do("DELETE FROM creatives WHERE campaignId=" . to_sql($db, $campaignId, "Number"));

			$db->do("DELETE FROM cam_payments WHERE campaignId=" . to_sql($db, $campaignId, "Number"));

			my $suppFile = DlookUp($db, "SELECT suppFile FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));
			if ($suppFile ne "")
			{
				unlink $options{SuppDir} . "/" . $campaignId;
			}
			$db->do("DELETE FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));
		}

		$db->do("DELETE FROM advertisers WHERE advertiserId=" . to_sql($db, $advertiserId, "Number"));
		

		$r->header_out(Location => 'admin?p=advertisers&mes=deleted');
		return REDIRECT;
	}

	my %fields = (
		email =>		{ title=>"Email", 						value=>"",	min=>7,	max=>120 },
		passwd =>		{ title=>"Password",					value=>"",	min=>5,	max=>32 },
		statusId =>		{ title=>"Status",		type=>"int",	value=>0,	min=>0,	max=>2,		nocheck=>1 },
		name =>			{ title=>"Name",						value=>"",	min=>2,	max=>64 },
		company =>		{ title=>"Company",						value=>"",	min=>2,	max=>64 },
		address1 =>		{ title=>"Address 1",					value=>"",	min=>2,	max=>128 },
		address2 =>		{ title=>"Address 2",					value=>"",	min=>0,	max=>128,	optional=>1 },
		city =>			{ title=>"City",						value=>"",	min=>2,	max=>64 },
		stateId=>		{ title=>"Sate",		type=>"int",	value=>0,	min=>0,	max=>1000,	nocheck=>1 },
		state =>		{ title=>"Non USA State",				value=>"",	min=>2,	max=>64,	nocheck=>1 },
		countryId =>	{ title=>"Country",		type=>"int",	value=>0,	min=>0,	max=>10000,	nocheck=>1 },
		zip =>			{ title=>"ZIP",							value=>"",	min=>2,	max=>32 },
		phone =>		{ title=>"Phone",						value=>"",	min=>2,	max=>64 },
		fax =>			{ title=>"Fax",							value=>"",	min=>2,	max=>64 },
		urlAdv =>		{ title=>"Url",							value=>"",	min=>2,	max=>128 },
		description =>	{ title=>"Description",					value=>"",	min=>2,	max=>255, optional=>1 },
		registered =>	{ title=>"Registered",	type=>"plain",	value=>"",						noupdate=>1, nohttp=>1, nocheck=>1 }
	);


#$sMessage = fields_to_sql($db, \%fields);



	# get values from http
	if ($cmd eq "create" || ($cmd eq "update" && $advertiserId > 0) || ($cmd eq "approve" && $advertiserId > 0))
	{
		get_http(\%fields);
	}

	# create new advertiser action
	if ($cmd eq "create")
	{

		$fields{registered}{value} = "now()";

#			"email,passwd,statusId,name,company,address1,address2,city,stateId,state,countryId,zip,phone,fax,url,description,registered" .
		$sql = "INSERT INTO advertisers (" .
			sql_fields($db, \%fields) .
			") VALUES (" .
			sql_values($db, \%fields) .
			")";			

		my $res = $db->do($sql);

		if ($res != 0)
		{
			$r->header_out(Location => "admin?p=advertisers&mes=created&" . get_params());
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
	}

	# update existed advertiser action
	if ($cmd eq "update" && $advertiserId > 0)
	{
		$sql = "UPDATE advertisers SET " .
			fields_to_sql($db, \%fields) .
			" WHERE advertiserId=" . to_sql($db, $advertiserId, "Number");

		my $res = $db->do($sql);

		if ($res != 0)
		{
			$r->header_out(Location => "admin?p=advertisers&mes=update&" . get_params());
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
	}

	# approve existed advertiser action
	if ($cmd eq "approve" && $advertiserId > 0)
	{
		$fields{statusId}{value} = 1;

		$sql = "UPDATE advertisers SET " .
			fields_to_sql($db, \%fields) .
			" WHERE advertiserId=" . to_sql($db, $advertiserId, "Number");

		my $res = $db->do($sql);

		if ($res != 0)		
		{
				my $tplMail = Ads::Template->new();
				$tplMail->LoadTemplate($options->{TemplatePath} . "/email/admin_adv_approve.html", "main", $options);
				$tplMail->setvar("advertiserId", $advertiserId);
				$tplMail->setvar("email", $fields{email}{value});
				$tplMail->setvar("passwd", $fields{passwd}{value});
				$tplMail->setvar("ServerURL", $options->{ServerURL});
				$tplMail->parse("main", "false");
				send_email(
					DLookUp($db, "SELECT email FROM advertisers WHERE advertiserId=" . to_sql($db, $advertiserId, "Number")),
					$options->{AdminEmail}, "Advertiser account is approved", $tplMail->getvar("main"), "text/html");

			$r->header_out(Location => "admin?p=advertisers&mes=approved&" . get_params());
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
	}

	# get values from db fro existed record
	if($advertiserId > 0)
	{
		get_db($db, \%fields, "FROM advertisers WHERE advertiserId=" . to_sql($db, $advertiserId, "Number"));
=comment
		my $st = $db->prepare("SELECT email,passwd,statusId,name,company,address1,address2,city,stateId,state,countryId,zip,phone,fax,url,description,registered" .
			" FROM advertisers WHERE advertiserId=" . to_sql($db, $advertiserId, "Number"));
		$st->execute;
		($email,$passwd,$statusId,$name,$company,$address1,$address2,$city,$stateId,$state,$countryId,$zip,$phone,$fax,$url,$description,$registered)
				= $st->fetchrow_array;
		$st->finish;
=cut
	}


	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/admin/advertiser.html", "main", $options);
	$Tpl->setvar("params", get_params());



	if ($advertiserId > 0)
	{
		# parse the grid of campaigns
		grid($options, $db, $Tpl, "campaigns", 
			"SELECT c.campaignId, c.name, ca.title as category, t.title as type, d.domain as domain," .
				"c.price, c.urlActual, s.title as status, c.account, c.registered, c.updated" .
				" FROM (((campaigns as c LEFT JOIN cam_types as t ON c.typeId=t.typeId)" .
				" LEFT JOIN categories as ca ON c.categoryId=ca.categoryId)" .
				" LEFT JOIN domains as d ON c.domainId=d.domainId)" .
				" LEFT JOIN cam_statuses as s ON c.statusId=s.statusId" .
				" WHERE c.advertiserId=" . to_sql($db, $advertiserId, "Number"),
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
				"link" => ["link", "admin?p=campaign&campaignId="]
			},
			"admin",
			"campaignId");
	}


#$sMessage = debug_params();

	$Tpl->setvar("sMessage", $sMessage);


	$Tpl->setvar("advertiserId", $advertiserId);

	$Tpl->setvar("advertiser_checks", html_checks(\%fields, "advertiser"));

	parse_values($Tpl, \%fields);

	#$Tpl->setvar("email", $email);
	#$Tpl->setvar("passwd", $passwd);
	$Tpl->setvar("statusOptions", DSelectOptions($db, "SELECT statusId, title FROM adv_statuses", $fields{statusId}{value}));
	#$Tpl->setvar("name", $name);
	#$Tpl->setvar("company", $company);
	#$Tpl->setvar("address1", $address1);
	#$Tpl->setvar("address2", $address1);
	#$Tpl->setvar("city", $city);
	$Tpl->setvar("statesOptions", DSelectOptions($db, "SELECT stateId, title FROM states", $fields{stateId}{value}));
	#$Tpl->setvar("state", $state);
	$Tpl->setvar("countriesOptions", DSelectOptions($db, "SELECT countryId, title FROM countries", $fields{countryId}{value}));
	#$Tpl->setvar("zip", $zip);
	#$Tpl->setvar("phone", $phone);
	#$Tpl->setvar("fax", $fax);
	#$Tpl->setvar("url", $url);
	#$Tpl->setvar("description", $description);
	#$Tpl->setvar("registered", $registered);

	if ($advertiserId > 0)
	{
		$Tpl->setvar("sTitle", "Advertiser #" . $advertiserId);
		$Tpl->setvar("sCmd", "Update");
		$Tpl->setvar("cmd", "update");
		$Tpl->parse("bDelete");

		if ($fields{statusId}{value} == 0)
		{
			$Tpl->parse("bApprove");
		}

	} else {
		$Tpl->setvar("sTitle", "New Advertiser");
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
