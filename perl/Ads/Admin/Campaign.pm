package Ads::Admin::Campaign;

#
# Campaign page of admin area
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

	my $sql = "";
	my $st = undef;

	get_block_params("aCampaign", $req);


	my $campaignId = get_param("campaignId", 0);

	my $advertiserId = get_param("advertiserId", 0);
	if ($advertiserId == 0)
	{
#		$r->header_out(Location => 'admin?p=advertisers');
#		return REDIRECT;
		$advertiserId = DLookUp($db, "SELECT advertiserId FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));
		$g_param_values{advertiserId} = $advertiserId;
	}




	# delete campaign
	if($campaignId > 0 && $cmd eq "delete")
	{
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

		$r->header_out(Location => 'admin?p=advertiser&mes=deleted');
		return REDIRECT;
	}



	my %fields = (
		name =>			{ title=>"Name", 						value=>"",	min=>2,	max=>64 },
		categoryId =>	{ title=>"Category",	type=>"int",	value=>"",	min=>5,	max=>32,	nocheck=>1 },
		domainId =>		{ title=>"Domain",		type=>"int",	value=>0,	min=>0,	max=>2,		nocheck=>1 },
		typeId =>		{ title=>"Type",		type=>"int",	value=>0,	min=>0,	max=>2,		nocheck=>1 },
		statusId =>		{ title=>"Status",		type=>"int",	value=>0,	min=>0,	max=>2,		nocheck=>1 },
		price =>		{ title=>"Advertiser Price",	type=>"float",	value=>0.0,	min=>0.0	 },
		priceNew =>		{ title=>"New Price",	type=>"float",	value=>0.0,	min=>0.0	 },
		priceCPM =>		{ title=>"Price CPM",		type=>"plain",	value=>0.0,	nohttp=>1, nocheck=>1	 },
		priceNewCPM =>	{ title=>"New Price CPM",	type=>"plain",	value=>0.0,	nohttp=>1, nocheck=>1	 },
		pricePub =>		{ title=>"Publisher Price",	type=>"float",	value=>0.0,	min=>0.0	 },
		pricePubCPM =>	{ title=>"Publisher Price CPM",	type=>"plain",	value=>0.0,	nohttp=>1, nocheck=>1	 },
		urlActual =>	{ title=>"Url",							value=>"",	min=>2,	max=>128 },
		urlNew =>		{ title=>"New Url",						value=>"",	min=>0,	max=>128,	optional=>1 },
		account =>		{ title=>"Account",		type=>"float",	value=>0.0 },
		registered =>	{ title=>"Registered",	type=>"plain",	value=>"",						noupdate=>1, nohttp=>1, nocheck=>1 },
		updated =>		{ title=>"Updated",		type=>"plain",	value=>"",						nohttp=>1, nocheck=>1 },
		suppFile =>		{ title=>"supFile",		type=>"plain",	value=>"",						noupdate=>1, noinsert=>1, nohttp=>1, nocheck=>1 }
	);
	

	# get values from db fro existed record
#	if($campaignId > 0)
#	{
#		get_db($db, \%fields, "FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));
#	}


	if ($cmd eq "delSupp")
	{
		unlink($options->{SuppDir} . "/" . $campaignId);
		$db->do("UPDATE campaigns SET suppFile=" . to_sql($db, "", "") . " WHERE campaignId=" . to_sql($db, $campaignId, "Number"));
	}

	# get values from http
	if ($cmd eq "create" || ($cmd eq "update" && $campaignId > 0) || ($cmd eq "approve" && $campaignId > 0))
	{
		get_http(\%fields);
		if ($fields{typeId}->{value} == 2) # if per 1000 views type then we need to have price for one view
		{
			$fields{priceCPM}->{value} = $fields{price}->{value} / 1000;
			$fields{priceNewCPM}->{value} = $fields{priceNew}->{value} / 1000;
			$fields{pricePubCPM}->{value} = $fields{pricePub}->{value} / 1000;
		}
		$fields{updated}{value} = "now()";

		# create new action
		if ($cmd eq "create")
		{

			$fields{registered}{value} = "now()";

			$sql = "INSERT INTO campaigns (" .
				sql_fields($db, \%fields) . ",advertiserId" .
				") VALUES (" .
				sql_values($db, \%fields) . "," . to_sql($db, $advertiserId, "Number") .
				")";			
		} else { # update & approve action

			if ($cmd eq "approve")
			{
				$fields{statusId}{value} = 1;
			}
			$sql = "UPDATE campaigns SET " .
				fields_to_sql($db, \%fields) .
				" WHERE campaignId=" . to_sql($db, $campaignId, "Number");
		}


#print "<hr>$sql<hr>";

		my $res = $db->do($sql);
		if ($cmd eq "create")
		{
			$campaignId = $db->{ q{mysql_insertid}};
		}

		if ($res != 0)
		{

			# get uploaded images
			my $upload = $req->upload("suppFile");
			if (defined $upload)
			{
				my $n;
				my $buf;
				my $sSuppFileName = $upload->filename;
				if ($sSuppFileName ne "")
				{
					$sSuppFileName =~ m/[\\\/]([^\\\/]*)$/g;
					$sSuppFileName = $1 if ($1 ne "");
	
#					$sMessage = $sSuppFileName;

					my $sSuppFile = $options->{SuppDir} . "/" . $campaignId;
					open SUPP, ">$sSuppFile";
					if ( ($n = read($upload->fh, $buf, $upload->size)) == $upload->size)
					{
						syswrite(SUPP, $buf, $n);
					}
					close(SUPP);
					$db->do("UPDATE campaigns SET suppFile=" . to_sql($db, $sSuppFileName, "") . " WHERE campaignId=" . to_sql($db, $campaignId, "Number"));
				}
			}

			if ($cmd eq "approve")
			{
				my $tplMail = Ads::Template->new();
				$tplMail->LoadTemplate($options->{TemplatePath} . "/email/admin_cam_approve.html", "main", $options);
				$tplMail->setvar("campaignId", $campaignId);
				$tplMail->setvar("campaign", DLookUp($db, "SELECT name FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number")));
				$tplMail->setvar("ServerURL", $options->{ServerURL});
				$tplMail->parse("main", "false");
				send_email(
					DLookUp($db, "SELECT email FROM advertisers WHERE advertiserId=" . to_sql($db, $advertiserId, "Number")),
					$options->{AdminEmail}, "Campaign is approved", $tplMail->getvar("main"), "text/html");
			}

			if ($cmd eq "create")
			{
				$r->header_out(Location => "admin?p=advertiser&mes=created&" . get_params());
			} elsif ($cmd eq "update") {
				$r->header_out(Location => "admin?p=advertiser&mes=updated&" . get_params());
			} else {
				$r->header_out(Location => "admin?p=advertiser&mes=approved&" . get_params());
			}
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
	}


	# get values from db fro existed record
	if($campaignId > 0)
	{
		get_db($db, \%fields, "FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));

	} else {
		$fields{domainId}{value} = DLookUp($db, "SELECT defaultDomainId FROM options");
	}

	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/admin/campaign.html", "main", $options);
	$Tpl->setvar("params", get_params());


	if ($campaignId > 0)
	{
		# parse the grid of creatives
		grid($options, $db, $Tpl, "creatives", 
			"SELECT c.creativeId, t.title as type," .
				"s.title as status, c.registered, c.updated" .
				" FROM (creatives as c LEFT JOIN cre_types as t ON c.typeId=t.typeId)" .
				" LEFT JOIN cre_statuses as s ON c.statusId=s.statusId" .
				" WHERE campaignId=" . to_sql($db, $campaignId, "Number"),
			"SELECT count(*) as cnt FROM creatives WHERE campaignId=" . to_sql($db, $campaignId, "Number"),
			{
				"creativeId" => ["creativeId", undef],
				"type" => ["type", undef],
				"status" => ["status", undef],
				"registered" => ["registered", undef],
				"updated" => ["updated", undef],
				"link" => ["link", "admin?p=creative&creativeId="]
			},
			"admin",
			"creativeId");

		# parse the grid of spec. pub. prices
		grid($options, $db, $Tpl, "pubprices",
			"SELECT p.publisherId, p.company, pcp.price" .
				" FROM pub_cams as pcp LEFT JOIN publishers as p ON p.publisherId=pcp.publisherId" .
				" WHERE pcp.campaignId=" . to_sql($db, $campaignId, "Number"),
			"SELECT count(*) as cnt FROM pub_cams as pcp LEFT JOIN publishers as p ON p.publisherId=pcp.publisherId WHERE pcp.campaignId=" . to_sql($db, $campaignId, "Number"),
			{
				"publisherId" => ["publisherId", undef],
				"company" => ["company", undef],
				"price" => ["price", undef],
				"link" => ["link", "admin?p=publisher&publisherId="]
			},
			"admin",
			"publisherId");

	}




#$sMessage = debug_params();

	$Tpl->setvar("sMessage", $sMessage);


	$Tpl->setvar("campaignId", $campaignId);
	$Tpl->setvar("advertiserId", $advertiserId);

	$Tpl->setvar("campaign_checks", html_checks(\%fields, "campaign"));

	parse_values($Tpl, \%fields);

	if ($fields{suppFile}{value})
	{
		$Tpl->parse("bSupp");
	} else {
		$Tpl->setvar("suppFile", "No file");
	}

	$Tpl->setvar("statusOptions", DSelectOptions($db, "SELECT statusId, title FROM cam_statuses", $fields{statusId}{value}));
	$Tpl->setvar("typeOptions", DSelectOptions($db, "SELECT typeId, title FROM cam_types", $fields{typeId}{value}));
	$Tpl->setvar("domainOptions", DSelectOptions($db, "SELECT domainId, domain FROM domains", $fields{domainId}{value}));
	$Tpl->setvar("categoryOptions", DSelectOptions($db, "SELECT categoryId, title FROM categories", $fields{categoryId}{value}));

	if ($campaignId > 0)
	{
		$Tpl->setvar("sTitle", "Campaign #" . $campaignId);
		$Tpl->setvar("sCmd", "Update");
		$Tpl->setvar("cmd", "update");
		$Tpl->parse("bDelete");
		$Tpl->parse("bPayments");
		if ($fields{statusId}{value} == 0 || $fields{statusId}{value} == 3)
		{
			$Tpl->parse("bApprove");
		}
    } else {
		$Tpl->setvar("sTitle", "New Campaign");
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
