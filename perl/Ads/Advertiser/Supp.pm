package Ads::Advertiser::Supp;

#
# Campaign page of advertiser area
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

	# if advertiser is not logged in then redirect to login
	if (get_session("advertiserId") eq "")
	{
		$r->header_out(Location => 'advertiser?p=login&mes=login');
		return REDIRECT;
	}



	my $cmd = $req->param("cmd");

	my $sMessage = "";
	my $db = $options->{db};
	get_block_params("adCampaign", $req);

	my $sql;



	my $advertiserId = get_session("advertiserId");
	my $campaignId = get_param("campaignId", 0);

	# check that campaign of current advertiser
	if ($campaignId > 0)
	{
		if ($advertiserId != DLookUp($db, "SELECT advertiserId FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number")))
		{
			$r->header_out(Location => 'advertiser?p=campaigns');
			return REDIRECT;
		}
	} else {
		$r->header_out(Location => 'advertiser?p=campaigns');
		return REDIRECT;
	}






	my $sFileName = DLookUp($db, "SELECT suppFile FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));
	if (! $sFileName)
	{
		$r->header_out(Location => 'advertiser?p=campaigns');
		return REDIRECT;
	}
	my $sPath = $options->{SuppDir} . "/" . $campaignId;
	if (open (F, $sPath))
	{
		binmode F;
		my $buf;
		my $size;
	    $r->content_type('application/x-download');
		$r->header_out("Content-disposition" => "attachment; filename=\"" . $sFileName . "\"");
    	$r->send_http_header;
		while ($size = read(F, $buf, 1024))
		{
			print $buf;
		}
		close F;
	    return OK;
	} else {
		$r->header_out(Location => 'advertiser?p=campaigns');
		return REDIRECT;
	}

}

1;
