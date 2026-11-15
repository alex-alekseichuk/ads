package Ads::Admin::Creative;

#
# Creative page of admin area
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
	get_block_params("aCreative", $req);

	my $sql = "";
	my $st = undef;


	# get creative from HTTP
	my $creativeId = get_param("creativeId", 0);
	my $campaignId = 0;

	# get campaign from HTTP or DB by creative
	if ($creativeId > 0)
	{
		$campaignId = DLookUp($db, "SELECT campaignId FROM creatives WHERE creativeId=" . to_sql($db, $creativeId, "Number"));
	} else {
		$campaignId = get_param("campaignId", 0);
	}

	# the campaign should be anyway
	if ($campaignId == 0)
	{
		$r->header_out(Location => 'admin?p=advertiser');
		return REDIRECT;
	}
	$g_param_values{campaignId} = $campaignId;

	# get advertiser from DB by campaign
	my $advertiserId = DLookUp($db, "SELECT advertiserId FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));
	if ($advertiserId == 0)
	{
		$r->header_out(Location => 'admin?p=advertisers');
		return REDIRECT;
	}
	$g_param_values{advertiserId} = $advertiserId;

	# upload image or other file as attached to the creative
	if ($creativeId > 0 && $cmd eq "uploadImg")
	{

		# get uploaded image
		my $upload = $req->upload("imgFile");
		if (defined $upload)
		{
			my $n;
			my $buf;
			my $sImgFileName = $upload->filename;
			if ($sImgFileName ne "")
			{
				$sImgFileName =~ m/[\\\/]([^\\\/]*)$/g;
				$sImgFileName = $1 if ($1 ne "");
	
				my $sImgFile = $options->{ImgDir} . "/" . $creativeId . "_" . $sImgFileName;

				open IMG, ">$sImgFile";
				if ( ($n = read($upload->fh, $buf, $upload->size)) == $upload->size)
				{
					syswrite(IMG, $buf, $n);
				}
				close(IMG);
				$db->do("INSERT INTO cre_imgs (name, creativeId) VALUES (" . to_sql($db, $sImgFileName, "") . "," . to_sql($db, $creativeId, "Number") . ")");
			}
		}
	}

	# delete attached image or file
	if ($creativeId > 0 && $cmd eq "delImg")
	{
		my $imgId = get_param("imgId", 0);
		if ($imgId > 0)
		{
			if (DLookUp($db, "SELECT creativeId FROM cre_imgs WHERE imgId=" . to_sql($db, $imgId, "Number")) == $creativeId)
			{
				my $sImgFile = $options->{ImgDir} . "/" . $creativeId . "_" . DLookUp($db, "SELECT name FROM cre_imgs WHERE imgId=" . to_sql($db, $imgId, "Number"));
				unlink($sImgFile);
				$db->do("DELETE FROM cre_imgs WHERE imgId=" . to_sql($db, $imgId, "Number"));
			}
		}
	}

	# delete creative
	if($creativeId > 0 && $cmd eq "delete")
	{
		$sql = "SELECT name FROM cre_imgs WHERE creativeId=" . to_sql($db, $creativeId, "Number");
		$st = $db->prepare($sql);
		$st->execute;
		while (my $row = $st->fetchrow_hashref() )
		{
			unlink $options{ImgDir} . "/" . $creativeId . "_" . $row->{name};
		}
		$st->finish;
		
		$db->do("DELETE FROM cre_imgs WHERE creativeId=" . to_sql($db, $creativeId, "Number"));
		$db->do("DELETE FROM creatives WHERE creativeId=" . to_sql($db, $creativeId, "Number"));
		$r->header_out(Location => 'admin?p=campaign&mes=deleted&' . get_params());
		return REDIRECT;
	}


	my %fields = (
		typeId =>		{ title=>"Type",		type=>"int",	value=>0,	min=>0,	max=>2,		nocheck=>1 },
		statusId =>		{ title=>"Status",		type=>"int",	value=>0,	min=>0,	max=>2,		nocheck=>1 },
		body =>			{ title=>"Body",						value=>"",	min=>0,	max=>$options->{MaxCreativeLen} 	},
		bodyNew =>		{ title=>"New Body",					value=>"",	min=>0,	max=>$options->{MaxCreativeLen},	optional=>1 },
		registered =>	{ title=>"Registered",	type=>"plain",	value=>"",						noupdate=>1, nohttp=>1, nocheck=>1 },
		updated =>		{ title=>"Updated",		type=>"plain",	value=>"",						nohttp=>1, nocheck=>1 }
	);


	# get values from http
	if ($cmd eq "create" || ($cmd eq "update" && $creativeId > 0) || ($cmd eq "approve" && $creativeId > 0))
	{
		get_http(\%fields);
	}

	# create new action
	if ($cmd eq "create")
	{

		$fields{registered}{value} = "now()";
		$fields{updated}{value} = "now()";

		$sql = "INSERT INTO creatives (" .
			sql_fields($db, \%fields) . ",campaignId" .
			") VALUES (" .
			sql_values($db, \%fields) . "," . to_sql($db, $campaignId, "Number") .
			")";			

		my $res = $db->do($sql);

		if ($res != 0)		
		{
			$r->header_out(Location => "admin?p=campaign&mes=created&" . get_params());
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
	}

	# update action
	if ($cmd eq "update" && $creativeId > 0)
	{
		$fields{updated}{value} = "now()";

		$sql = "UPDATE creatives SET " .
			fields_to_sql($db, \%fields) .
			" WHERE creativeId=" . to_sql($db, $creativeId, "Number");

		my $res = $db->do($sql);

		if ($res != 0)		
		{
			$r->header_out(Location => "admin?p=campaign&mes=updated&" . get_params());
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
	}

	# approve action
	if ($cmd eq "approve" && $creativeId > 0)
	{
		$fields{updated}{value} = "now()";
		$fields{statusId}{value} = 1;

		$sql = "UPDATE creatives SET " .
			fields_to_sql($db, \%fields) .
			" WHERE creativeId=" . to_sql($db, $creativeId, "Number");

		my $res = $db->do($sql);

		if ($res != 0)		
		{
			my $tplMail = Ads::Template->new();
			$tplMail->LoadTemplate($options->{TemplatePath} . "/email/admin_cre_approve.html", "main", $options);
			$tplMail->setvar("campaignId", $campaignId);
			$tplMail->setvar("campaign", DLookUp($db, "SELECT name FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number")));
			$tplMail->setvar("creativeId", $creativeId);
			$tplMail->setvar("ServerURL", $options->{ServerURL});
			$tplMail->parse("main", "false");
			send_email(
				DLookUp($db, "SELECT email FROM advertisers WHERE advertiserId=" . to_sql($db, $advertiserId, "Number")),
				$options->{AdminEmail}, "Creative is approved", $tplMail->getvar("main"), "text/html");

			$r->header_out(Location => "admin?p=campaign&mes=approved&" . get_params());
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
	}

	# get values from db fro existed record
	if($campaignId > 0)
	{
		get_db($db, \%fields, "FROM creatives WHERE creativeId=" . to_sql($db, $creativeId, "Number"));
	}


	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/admin/creative.html", "main", $options);
	$Tpl->setvar("params", get_params());

	if ($creativeId > 0)
	{
		# parse the grid of images and other files
		grid($options, $db, $Tpl, "imgs", 
			"SELECT i.imgId, i.name" .
				" FROM cre_imgs as i" .
				" WHERE creativeId=" . to_sql($db, $creativeId, "Number"),
			"SELECT count(*) as cnt FROM cre_imgs WHERE creativeId=" . to_sql($db, $creativeId, "Number"),
			{
				"creativeId" => ["creativeId", $creativeId],
				"imgId" => ["imgId", undef],
				"name" => ["name", undef],
				"ImgURL" => ["ImgURL", $options{ImgURL}]
			},
			"admin",
			"imgId");		
	}

#$sMessage = debug_params();

	$Tpl->setvar("sMessage", $sMessage);


	$Tpl->setvar("creativeId", $creativeId);
	$Tpl->setvar("campaignId", $campaignId);
	$Tpl->setvar("advertiserId", $advertiserId);

	$Tpl->setvar("creative_checks", html_checks(\%fields, "creative"));

	parse_values($Tpl, \%fields);

	$Tpl->setvar("statusOptions", DSelectOptions($db, "SELECT statusId, title FROM cre_statuses", $fields{statusId}{value}));
	$Tpl->setvar("typeOptions", DSelectOptions($db, "SELECT typeId, title FROM cre_types", $fields{typeId}{value}));

	if ($creativeId > 0)
	{
		$Tpl->setvar("sTitle", "Creative #" . $creativeId);
		$Tpl->setvar("sCmd", "Update");
		$Tpl->setvar("cmd", "update");
		$Tpl->parse("bDelete");
		if ($fields{statusId}{value} == 0 || $fields{statusId}{value} == 3)
		{
			$Tpl->parse("bApprove");
		}
    } else {
		$Tpl->setvar("sTitle", "New Creative");
		$Tpl->setvar("sCmd", "Create");
		$Tpl->setvar("cmd", "create");
	}


	$Tpl->setvar("MaxCreativeLen", $options->{MaxCreativeLen});



	HeaderFooter($Tpl);

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");

	$r->send_http_header('text/html');
	print $main_block;

    return OK;
}

1;
