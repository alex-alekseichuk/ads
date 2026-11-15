package Ads::Admin::Publisher;

#
# publisher page of admin area
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
	get_block_params("aPublisher", $req);

	my $sql;

	my $publisherId = get_param("publisherId", 0);


	# delete publisher
	if($publisherId > 0 && $cmd eq "delete")
	{
		$db->do("DELETE FROM pub_payments WHERE publisherId=" . to_sql($db, $publisherId, "Number"));
		$db->do("DELETE FROM publishers WHERE publisherId=" . to_sql($db, $publisherId, "Number"));
		$r->header_out(Location => 'admin?p=publishers&mes=deleted');
		return REDIRECT;
	}

	my %fields = (
		email =>		{ title=>"Email", 						value=>"",	min=>7,	max=>120 },
		passwd =>		{ title=>"Password",					value=>"",	min=>5,	max=>32 },
		statusId =>		{ title=>"Status",		type=>"int",	value=>0,	min=>0,	max=>2,		nocheck=>1 },
		account =>		{ title=>"Account",		type=>"float",	value=>0,						noinsert=>1, noupdate=>1, nohttp=>1, nocheck=>1 },
		name =>			{ title=>"Name",						value=>"",	min=>2,	max=>64 },
		company =>		{ title=>"Comapny",						value=>"",	min=>2,	max=>64 },
		address1 =>		{ title=>"Address 1",					value=>"",	min=>2,	max=>128 },
		address2 =>		{ title=>"Address 2",					value=>"",	min=>0,	max=>128,	optional=>1 },
		city =>			{ title=>"City",						value=>"",	min=>2,	max=>64 },
		stateId=>		{ title=>"Sate",		type=>"int",	value=>0,	min=>0,	max=>1000,	nocheck=>1 },
		state =>		{ title=>"Non USA State",				value=>"",	min=>2,	max=>64,	nocheck=>1 },
		countryId =>	{ title=>"Country",		type=>"int",	value=>0,	min=>0,	max=>10000,	nocheck=>1 },
		zip =>			{ title=>"ZIP",							value=>"",	min=>2,	max=>32 },
		phone =>		{ title=>"Phone",						value=>"",	min=>2,	max=>64 },
		fax =>			{ title=>"Fax",							value=>"",	min=>2,	max=>64 },
		urlPub =>		{ title=>"Url",							value=>"",	min=>2,	max=>128 },
		description =>	{ title=>"Description",					value=>"",	min=>2,	max=>255 },
		registered =>	{ title=>"Registered",	type=>"plain",	value=>"",						noupdate=>1, nohttp=>1, nocheck=>1 }
	);



#$sMessage = fields_to_sql($db, \%fields);



	# get values from http
	if ($cmd eq "create" || (($cmd eq "update" || $cmd eq "approve") && $publisherId > 0))
	{
		get_http(\%fields);

	}

	# create new action
	if ($cmd eq "create")
	{

		$fields{registered}{value} = "now()";

		$sql = "INSERT INTO publishers (" .
			sql_fields($db, \%fields) .
			") VALUES (" .
			sql_values($db, \%fields) .
			")";			

		my $res = $db->do($sql);

		if ($res != 0)		
		{
			$r->header_out(Location => "admin?p=publishers&mes=created&" . get_params());
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
	}


	# update existed 
	if ($cmd eq "update" && $publisherId > 0)
	{
		$sql = "UPDATE publishers SET " .
			fields_to_sql($db, \%fields) .
			" WHERE publisherId=" . to_sql($db, $publisherId, "Number");

=commnet
$r->send_http_header('text/html');
print $sql;
return OK;
=cut


		my $res = $db->do($sql);

		if ($res != 0)		
		{
			$r->header_out(Location => "admin?p=publishers&mes=updated&" . get_params());
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
	}

	# approve existed 
	if ($cmd eq "approve" && $publisherId > 0)
	{
		$fields{statusId}{value} = 1;

		$sql = "UPDATE publishers SET " .
			fields_to_sql($db, \%fields) .
			" WHERE publisherId=" . to_sql($db, $publisherId, "Number");

		my $res = $db->do($sql);

		if ($res != 0)		
		{
			my $tplMail = Ads::Template->new();
			$tplMail->LoadTemplate($options->{TemplatePath} . "/email/admin_pub_approve.html", "main", $options);
			$tplMail->setvar("publisherId", $publisherId);
			$tplMail->setvar("email", $fields{email}{value});
			$tplMail->setvar("passwd", $fields{passwd}{value});
			$tplMail->setvar("ServerURL", $options->{ServerURL});
			$tplMail->parse("main", "false");
			send_email(
				DLookUp($db, "SELECT email FROM publishers WHERE publisherId=" . to_sql($db, $publisherId, "Number")),
				$options->{AdminEmail}, "Publisher account is approved", $tplMail->getvar("main"), "text/html");

			$r->header_out(Location => "admin?p=publishers&mes=updated&" . get_params());
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
	}

	# get values from db fro existed record
	if($publisherId > 0)
	{
		get_db($db, \%fields, "FROM publishers WHERE publisherId=" . to_sql($db, $publisherId, "Number"));
	}


	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/admin/publisher.html", "main", $options);
	$Tpl->setvar("params", get_params());

	if ($publisherId > 0)
	{
		# parse the grid of spec. cam. prices
		grid($options, $db, $Tpl, "pubprices",
			"SELECT c.campaignId, c.name, pcp.price" .
				" FROM pub_cams as pcp LEFT JOIN campaigns as c ON c.campaignId=pcp.campaignId" .
				" WHERE pcp.publisherId=" . to_sql($db, $publisherId, "Number"),
			"SELECT count(*) as cnt FROM pub_cams as pcp LEFT JOIN campaigns as c ON c.campaignId=pcp.campaignId WHERE pcp.publisherId=" . to_sql($db, $publisherId, "Number"),
			{
				"campaignId" => ["campaignId", undef],
				"name" => ["name", undef],
				"price" => ["price", undef],
				"link" => ["link", "admin?p=campaign&campaignId="]
			},
			"admin",
			"campaignId");
	}
#$sMessage = debug_params();

	$Tpl->setvar("sMessage", $sMessage);


	$Tpl->setvar("publisherId", $publisherId);

	$Tpl->setvar("publisher_checks", html_checks(\%fields, "publisher"));

	parse_values($Tpl, \%fields);

	$Tpl->setvar("statusOptions", DSelectOptions($db, "SELECT statusId, title FROM adv_statuses", $fields{statusId}{value}));
	$Tpl->setvar("statesOptions", DSelectOptions($db, "SELECT stateId, title FROM states", $fields{stateId}{value}));
	$Tpl->setvar("countriesOptions", DSelectOptions($db, "SELECT countryId, title FROM countries", $fields{countryId}{value}));

	if ($publisherId > 0)
	{
		$Tpl->setvar("sTitle", "Publisher #" . $publisherId);
		$Tpl->setvar("sCmd", "Update");
		$Tpl->setvar("cmd", "update");
		$Tpl->parse("bDelete");
		$Tpl->parse("bPayments");

		if ($fields{statusId}{value} == 0)
		{
			$Tpl->parse("bApprove");
		}

	} else {
		$Tpl->setvar("sTitle", "New Publisher");
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
