package Ads::Publisher::Supp;

#
# Campaign page of publisher area
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
	get_block_params("puCampaign", $req);

	my $sql;


	my $publisherId = get_session("publisherId");
	my $campaignId = get_param("campaignId", 0);

	# check that campaign of current publisher
	if ($campaignId == 0)
	{
		$r->header_out(Location => 'publisher?p=campaigns');
		return REDIRECT;
	}

	my $statusId = DLookUp($db, "SELECT statusId FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));
	if ($statusId != 1 && $statusId != 3)
	{
		$r->header_out(Location => 'publisher?p=campaigns');
		return REDIRECT;
	}









	my $sFileName = DLookUp($db, "SELECT suppFile FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));
	if (! $sFileName)
	{
		$r->header_out(Location => 'publisher?p=campaigns');
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
		$r->header_out(Location => 'publisher?p=campaigns');
		return REDIRECT;
	}

}

1;
