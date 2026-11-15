package Ads::Publisher::Creative;

#
# Creative page of advetiser area
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
	get_block_params("puCreative", $req);

	my $sql = "";
	my $st = undef;


	my $publisherId = get_session("publisherId");
	my $creativeId = get_param("creativeId", 0);

	if ($creativeId == 0)
	{
		$r->header_out(Location => 'publisher?p=campaigns');
		return REDIRECT;
	}

	my $campaignId = DLookUp($db, "SELECT campaignId FROM creatives WHERE creativeId=" . to_sql($db, $creativeId, "Number"));

	my $statusId = DLookUp($db, "SELECT statusId FROM creatives WHERE creativeId=" . to_sql($db, $creativeId, "Number"));
	if ($statusId != 1 && $statusId != 3)
	{
		$r->header_out(Location => 'publisher?p=campaign&campaignId=' . $campaignId);
		return REDIRECT;
	}

	$statusId = DLookUp($db, "SELECT statusId FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));
	if ($statusId != 1 && $statusId != 3)
	{
		$r->header_out(Location => 'publisher?p=campaigns');
		return REDIRECT;
	}



	my $domainId = DLookUp($db, "SELECT domainId FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));
	if ($domainId == 0)
	{
		$domainId = 1;
	}
	my $domain = DLookUp($db, "SELECT domain FROM domains WHERE domainId=" . to_sql($db, $domainId, "Number"));

	my %fields = (
		typeId =>		{ title=>"Type",		type=>"int",	value=>0,	min=>0,	max=>2,		nocheck=>1 },
		registered =>	{ title=>"Registered",	type=>"plain",	value=>"",						noupdate=>1, nohttp=>1, nocheck=>1 },
		updated =>		{ title=>"Updated",		type=>"plain",	value=>"",						nohttp=>1, nocheck=>1 }
	);
#		body =>			{ title=>"Body",						value=>"",	min=>0,	max=>$options->{MaxCreativeLen},	noupdate=>1, nohttp=>1, nocheck=>1, noinsert=>1	},




	# get values from db for existed record
	if($creativeId > 0)
	{
		get_db($db, \%fields, "FROM creatives WHERE creativeId=" . to_sql($db, $creativeId, "Number"));
	}


	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/publisher/creative.html", "main", $options);
	$Tpl->setvar("params", get_params());

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
		"publisher",
		"imgId");		

#$sMessage = debug_params();

	$Tpl->setvar("sMessage", $sMessage);


	$Tpl->setvar("creativeId", $creativeId);
	$Tpl->setvar("publisherId", $publisherId);
	$Tpl->setvar("campaignId", $campaignId);
	$Tpl->setvar("domain", $domain);

	parse_values($Tpl, \%fields);

#	$Tpl->setvar("status", DLookUp($db, "SELECT title FROM cre_statuses WHERE statusId=" . to_sql($db, $fields{statusId}{value}, "Number")));
	$Tpl->setvar("type", DLookUp($db, "SELECT title FROM cre_types WHERE typeId=" . to_sql($db, $fields{typeId}{value}, "Number")));




	my $typeId = $fields{typeId}{value};
	my $sText = DLookUp($db, "SELECT body FROM creatives WHERE creativeId=" . to_sql($db, $creativeId, "Number"));

	if ($typeId == 2)
	{
		my $sImgURL = "http://" . $domain . $options{ServerURI} . $options{ImgSubDir} . "/";
		$sql = "SELECT name FROM cre_imgs WHERE creativeId=" . to_sql($db, $creativeId, "Number");
		$st = $db->prepare($sql);
		$st->execute;
		while (my $row = $st->fetchrow_hashref() )
		{
			my $name = $row->{name};
			my $newName = $sImgURL . $creativeId . "_" . $name;
			$sText =~ s/\"$name\"/("\"".$newName."\"")/ge;
			$sText =~ s/\'$name\'/("\'".$newName."\'")/ge;
		}
		$st->finish;

		# add 1x1 view tracker for publisher only
		my $trackView = "<img width=0 height=0 border=0 src=\"http://" . $domain . $options{ServerURI} . "action?a=v&c=" . $campaignId . "&p=" . $publisherId . "&r=" . $creativeId . "&s={s}\">";
		#my $trackView = "";
		$sText =~ s/\<\!--1x1--\>/$trackView/ge;
	}

	# parse {url}
	#$urlActual =~ s/\{c\}/$campaignId/ge;
	#$sText =~ s/\{url\}/$urlActual/ge;
	#
	my $urlClick = "http://" . $domain . $options{ServerURI} . "action?a=c&c=" . $campaignId . "&p=" . $publisherId . "&s={s}";
	$sText =~ s/\{url\}/$urlClick/ge;

	my $sText2 = $sText;
	$sText2 =~ s/\{s\}/-=ss=-/g;
	$sText2 =~ s/\"/\\\"/g;
	$sText2 =~ s/(\r\n)/\" \+$1\"/g;
	$sText2 =~ s/(\n\r)/\" \+$1\"/g;
	#$sText2 =~ s/(\r)/\" \+\1\"/g;
	#$sText2 =~ s/(\n)/\" \+\1\"/g;
	$Tpl->setvar("bodyText", $sText2);

	$sText =~ s/\{s\}//ge;
	$Tpl->setvar("body", $sText);




	HeaderFooter($Tpl);

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");

	$r->send_http_header('text/html');
	print $main_block;

    return OK;
}

1;
