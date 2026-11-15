package Ads::Publisher::Preview;

#
# Preview Creative page of publisher area
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
	my $db = $options->{db};
	my $sql = "";
	my $st = undef;

	# if publisher is not logged in then redirect to login
	if (get_session("publisherId") eq "")
	{
		$r->header_out(Location => 'publisher?p=login&mes=login');
		return REDIRECT;
	}

	my $publisherId = get_session("publisherId");
	my $subId = get_param("subId", "");

	my $creativeId = get_param("creativeId", 0);
	my $campaignId = 0;
	if ($creativeId > 0)
	{
		$campaignId = DLookUp($db, "SELECT campaignId FROM creatives WHERE creativeId=" . to_sql($db, $creativeId, "Number"));
	} else {
		$r->header_out(Location => 'publisher?p=campaign');
		return REDIRECT;
	}

	my $domain = DLookUp($db, "SELECT d.domain FROM domains AS d, campaigns AS c WHERE d.domainId=c.domainId AND c.campaignId=" . to_sql($db, $campaignId, "Number"));

	my $sText = "";
	my $typeId = DLookUp($db, "SELECT typeId FROM creatives WHERE creativeId=" . to_sql($db, $creativeId, "Number"));
#	my $bNew = get_param("bNew", 0);
#	if ($bNew == 0) # current body
#	{
		$sText = DLookUp($db, "SELECT body FROM creatives WHERE creativeId=" . to_sql($db, $creativeId, "Number"));
#	} else { # new body
#		$sText = DLookUp($db, "SELECT bodyNew FROM creatives WHERE creativeId=" . to_sql($db, $creativeId, "Number"));
#	}

#	my $Tpl = Ads::Template->new();
#	$Tpl->LoadTemplate($options->{TemplatePath} . "/publisher/preview.html", "main", $options);

#	$Tpl->setvar("text", $sText);


#	$Tpl->parse("main", "false");
#	my $main_block = $Tpl->getvar("main");


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
	#$urlActual =~ s/\{c\}/$campaignId/ge;
	#$sText =~ s/\{url\}/$urlActual/ge;
	#
	my $urlClick = "http://" . $domain . $options{ServerURI} . "action?a=c&c=" . $campaignId . "&p=" . $publisherId . "&s=" . $subId;
	$sText =~ s/\{url\}/$urlClick/ge;


	$r->send_http_header($typeId == 1 ? "text/plain" : "text/html");
#	print $main_block;
	print $sText;

    return OK;
}

1;
