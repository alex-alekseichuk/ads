package Ads::Admin::RepAdvertiser;

#
# Reports #5 advertiser page of admin area
#

use strict;
use Apache::Constants qw(:common);
use Apache::Request ();
use Apache::Cookie ();
use DBI;

use Date::Calc qw(Add_Delta_Days Days_in_Month);

use Ads::Common ;
use Ads::Template ;
use Ads::Grid ;

use Ads::Admin::Common;



sub process {
    my $options = shift;

	my $r = $options->{r};
	my $req = $options->{req};

	my $sCheck = checkAdminGrants(3);
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

	my $advertiserId = $req->param("advertiserId");

	# advertiser ?
	if ($advertiserId eq "")
	{
		$r->header_out(Location => 'admin?p=rep_advertisers');
		return REDIRECT;
	}

	my $db = $options->{db};
	my $sql = "";
	my $st = undef;

	get_block_params("aRepAdvertiser", $req);

	my $cmd = $req->param("cmd");



	my $sFrom = $req->param("dFrom");
	my $sTo = $req->param("dTo");

	if ($cmd eq "all")
	{
		$sFrom = "";
		$sTo = "";
	}
	if ($cmd eq "today")
	{
		my ($d, $m, $y) = (localtime)[3,4,5];
		$y += 1900;
		$m ++;
		$sFrom = join("-", ($y, $m, $d));
		$sTo = $sFrom;
	}
	if ($cmd eq "7days")
	{
		my ($d, $m, $y) = (localtime)[3,4,5];
		$y += 1900;
		$m ++;
		$sTo = join("-", ($y, $m, $d));
		my ($y2, $m2, $d2) = Add_Delta_Days($y, $m, $d, -6);
		$sFrom = join("-", ($y2, $m2, $d2));
	}
	if ($cmd eq "month")
	{
		my ($d, $m, $y) = (localtime)[3,4,5];
		$y += 1900;
		$m ++;
		$sFrom = join("-", ($y, $m, 1));
		$sTo = join("-", ($y, $m, $d));
	}
	if ($cmd eq "prevmonth")
	{
		my ($d, $m, $y) = (localtime)[3,4,5];
		$y += 1900;
		$m ++;
		$m --;
		if ($m <= 0)
		{
			$m = 12;
			$y --;
		}
		$sFrom = join("-", ($y, $m, 1));
		$sTo = join("-", ($y, $m, Days_in_Month($y, $m)));
	}

	$g_param_values{dFrom} = $sFrom;
	$g_param_values{dTo} = $sTo;



	my $sWhere = "ad.advertiserId=" . to_sql($db, $advertiserId, "Number");
	if ($sFrom ne "")
	{
		$sWhere .= " AND " if ($sWhere ne "");
		$sWhere .= "a.done>=" . to_sql($db, $sFrom, "");
	}
	if ($sTo ne "")
	{
		$sWhere .= " AND " if ($sWhere ne "");
		$sWhere .= "a.done<=" . to_sql($db, $sTo, "");
	}
	if ($sWhere ne "")
	{
		$sWhere = " WHERE " . $sWhere;
	}

	$sql = "SELECT c.campaignId, c.name, if(sum(a.views) is null,0,sum(a.views)) as views, if(sum(a.clicks) is null,0,sum(a.clicks)) as clicks, if(sum(a.sales) is null,0,sum(a.sales)) as sales, c.price," .
			" (if(c.typeId=0,(if(sum(a.sales) is null,0,sum(a.sales))) * c.price,if(c.typeId=1,(if(sum(a.clicks) is null,0,sum(a.clicks))) * c.price,(if(sum(a.views) is null,0,sum(a.views))) * c.priceCPM))) AS total" .
			" FROM (advertisers as ad JOIN campaigns AS c ON ad.advertiserId=c.advertiserId) JOIN actions AS a ON a.campaignId=c.campaignId" . $sWhere . " GROUP BY c.campaignId";

	if ($cmd eq "csv")
	{
		my $sPeriod = "all";
		if ($sFrom ne "" || $sTo ne "")
		{
			$sPeriod = $sFrom . "_" . $sTo;
		}
		my $sFileName = "advertiser_" . $sPeriod . ".csv";

		my $csv = "";

		my $st = $db->prepare($sql);
		$st->execute;
		while (my $row = $st->fetchrow_hashref() )
		{
			$csv .=
				$row->{campaignId} . "," .
				$row->{name} . "," .
				$row->{views} . "," .
				$row->{clicks} . "," .
				$row->{sales} . "," .
				$row->{price} . "," .
				$row->{total} . "\n";
		}
		$st->finish;

	    $r->content_type('application/x-download');
		$r->header_out("Content-disposition" => "attachment; filename=\"" . $sFileName . "\"");
    	$r->send_http_header;

		print $csv;

	    return OK;
	}

	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/admin/rep_advertiser.html", "main", $options);
	$Tpl->setvar("params", get_params());

	$Tpl->setvar("dFrom", $sFrom);
	$Tpl->setvar("dTo", $sTo);

	$Tpl->setvar("advertiserId", $advertiserId);

	# parse the grid of advertiser
	grid($options, $db, $Tpl, "campaigns", $sql,
		"SELECT count(distinct c.campaignId) as cnt FROM (advertisers as ad JOIN campaigns AS c ON ad.advertiserId=c.advertiserId) JOIN actions AS a ON a.campaignId=c.campaignId" . $sWhere . " GROUP BY c.campaignId",
		{
			"campaignId" => ["campaignId", undef],
			"name" => ["name", undef],
			"views" => ["views", undef],
			"clicks" => ["clicks", undef],
			"sales" => ["sales", undef],
			"price" => ["price", undef],
			"total" => ["total", undef]
		},
		"admin",
		"campaignId");




	HeaderFooter($Tpl);


#	$Tpl->setvar("sMessage", debug_params());

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");


	$r->send_http_header('text/html');
	print $main_block;

    return OK;
}

1;