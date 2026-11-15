package Ads::Admin::Supp;

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

	my $advertiserId = get_param("advertiserId", 0);
	if ($advertiserId == 0)
	{
		$r->header_out(Location => 'admin?p=advertisers');
		return REDIRECT;
	}

	my $campaignId = get_param("campaignId", 0);
	if ($campaignId == 0)
	{
		$r->header_out(Location => 'admin?p=advertiser');
		return REDIRECT;
	}






	my $cmd = $req->param("cmd");

	my $sMessage = "";
	my $db = $options->{db};
	get_block_params("aCampaign", $req);

	my $sql;



	my $sFileName = DLookUp($db, "SELECT suppFile FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));
	if (! $sFileName)
	{
		$r->header_out(Location => 'admin?p=advertiser');
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
		$r->header_out(Location => 'admin?p=advertiser');
		return REDIRECT;
	}

}

1;
