package Ads::Advertiser::Preview;

#
# Preview Creative page of advertiser area
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
	my $db = $options->{db};
	my $sql = "";
	my $st = undef;

	# if advertiser is not logged in then redirect to login
	if (get_session("advertiserId") eq "")
	{
		$r->header_out(Location => 'advertiser?p=login&mes=login');
		return REDIRECT;
	}

	my $advertiserId = get_session("advertiserId");

	# 0 - from DB
	# 1 - new value from DB
	# 2 - new value from HTTP
	my $bNew = get_param("bNew", 0);

	my $typeId = 1; # Plain text by default

	my $creativeId = get_param("creativeId", 0);

	if ($bNew == 2)
	{
		$typeId = get_param("typeId", 1);
	} else {
		$typeId = DLookUp($db, "SELECT typeId FROM creatives WHERE creativeId=" . to_sql($db, $creativeId, "Number"));
	}

	# get campaignId
	my $campaignId = 0;
	if ($creativeId == 0)
	{
		$campaignId = get_param("campaignId", 0);
	} else {
		$campaignId = DLookUp($db, "SELECT campaignId FROM creatives WHERE creativeId=" . to_sql($db, $creativeId, "Number"));
	}
	if ($campaignId == 0)
	{
		$r->header_out(Location => 'admin?p=advertiser');
		return REDIRECT;
	}
	if ($advertiserId != DLookUp($db, "SELECT advertiserId FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number")))
	{
		$r->header_out(Location => 'advertiser?p=campaigns');
		return REDIRECT;
	}


	my $sText = "";
	if ($bNew == 0) # current body
	{
		$sText = DLookUp($db, "SELECT body FROM creatives WHERE creativeId=" . to_sql($db, $creativeId, "Number"));
	} elsif ($bNew == 1) { # new saved body
		$sText = DLookUp($db, "SELECT bodyNew FROM creatives WHERE creativeId=" . to_sql($db, $creativeId, "Number"));
	} else {
		$sText = get_param("text", "");
	}

#	my $Tpl = Ads::Template->new();
#	$Tpl->LoadTemplate($options->{TemplatePath} . "/advertiser/preview.html", "main", $options);

#	$Tpl->setvar("text", $sText);


#	$Tpl->parse("main", "false");
#	my $main_block = $Tpl->getvar("main");


	my $domain = DLookUp($db, "SELECT d.domain FROM domains AS d, campaigns AS c WHERE d.domainId=c.domainId AND c.campaignId=" . to_sql($db, $campaignId, "Number"));
	my $urlActual = DLookUp($db, "SELECT urlActual FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));

	# we need to profide correct path to images and other attached files
	# for HTML creative
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
		#my $trackView = "<img width=0 height=0 border=0 src=\"http://" . $domain . $options{ServerURI} . "action?a=v&c=" . $campaignId . "&p={p}&r=" . $creativeId . "&s={s}\">";
		my $trackView = "";
		$sText =~ s/\<\!--1x1--\>/$trackView/ge;
	}

	# parse {url}
	$urlActual =~ s/\{c\}/$campaignId/ge;
	$sText =~ s/\{url\}/$urlActual/ge;


	$r->send_http_header($typeId == 1 ? "text/plain" : "text/html");
#	print $main_block;
	print $sText;

    return OK;
}

1;
