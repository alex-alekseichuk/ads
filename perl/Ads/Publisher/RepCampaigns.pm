package Ads::Publisher::RepCampaigns;

#
# Reports campaigns page of Publisher area
#

use strict;
use Apache::Constants qw(:common);
use Apache::Request ();
use Apache::Cookie ();

use Date::Calc qw(Add_Delta_Days Days_in_Month);

use Ads::Common ;
use Ads::Template ;
use Ads::Grid ;

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

	my $publisherId = get_session("publisherId");

	my $db = $options->{db};
	my $sql = "";
	my $st = undef;

	get_block_params("puRepCampaigns", $req);

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



	my $sWhere = "a.publisherId=" . to_sql($db, $publisherId, "Number");
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


	$sql = "SELECT c.campaignId, c.name," .
		" if(sum(a.views) is null,0,sum(a.views)) as views, if(sum(a.clicks) is null,0,sum(a.clicks)) as clicks, if(sum(a.sales) is null,0,sum(a.sales)) as sales," .
		" if(c.typeId=2,a.price*1000,a.price) as price," .
		" (if(c.typeId=0,(if(sum(a.sales) is null,0,sum(a.sales))) * a.price,if(c.typeId=1,(if(sum(a.clicks) is null,0,sum(a.clicks))) * a.price,(if(sum(a.views) is null,0,sum(a.views))) * a.price))) AS total" .
		" FROM actions AS a JOIN campaigns AS c ON a.campaignId=c.campaignId" . $sWhere . " GROUP BY c.campaignId,a.price";

	if ($cmd eq "csv")
	{
		my $sPeriod = "all";
		if ($sFrom ne "" || $sTo ne "")
		{
			$sPeriod = $sFrom . "_" . $sTo;
		}
		my $sFileName = "campaigns_" . $sPeriod . ".csv";

		my $csv = "";

		my $st = $db->prepare($sql);
		$st->execute;
		while (my $row = $st->fetchrow_hashref() )
		{
			$csv .=
				$row->{campaignId} . "," .
				$row->{company} . "," .
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
	$Tpl->LoadTemplate($options->{TemplatePath} . "/publisher/rep_campaigns.html", "main", $options);
	$Tpl->setvar("params", get_params());

	$Tpl->setvar("dFrom", $sFrom);
	$Tpl->setvar("dTo", $sTo);

	# parse the grid of campaigns
	grid($options, $db, $Tpl, "campaigns", $sql,
		"SELECT count(distinct c.campaignId) as cnt FROM actions AS a JOIN campaigns AS c ON a.campaignId=c.campaignId" . $sWhere . " GROUP BY c.campaignId",
		{
			"campaignId" => ["campaignId", undef],
			"name" => ["name", undef],
			"views" => ["views", undef],
			"clicks" => ["clicks", undef],
			"sales" => ["sales", undef],
			"price" => ["price", undef],
			"total" => ["total", undef]
		},
		"publisher",
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