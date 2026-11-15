package Ads::Action::Sale;

#
# Sale action
# used CPA-(per sale) campaigns only
#
# it's just the url like: http://server/proc/action?a=s&...
# it's 1x1 pixel code: <img width="1" height="1" src="..." />
# advertiser should go by that url each time there is sale action's done
# 
# a=s
# c - campaignId
# cookies:
#   adsp{campaignId} - publisherId
#   adss{campaignId} - subId
#
#
# e.g.
# http://localhost:8081/ads/proc/action?a=s&c=9
#





use strict;
use Apache::Constants qw(:common);
use Apache::Request ();
use Apache::Cookie ();
use DBI;

use Ads::Common ;
use Ads::Template ;

#use Ads::Action::Common;


sub process {
    my $options = shift;

	my $r = $options->{r};
	my $req = $options->{req};

	my $sMessage = "";
	my $db = $options->{db};
	my $st;


	# get parameters of action ------------------------------------

	my $campaignId = get_param("c", 0);
	if ($campaignId == 0)
	{
		$r->header_out(Location => 'action?a=incorrect');
		return REDIRECT;
	}

	# try to get paublisher from cookies
	my $bCookieMode = 0;
	my $ip = $r->connection->remote_ip;
	my $agent = $r->header_in("User-Agent");
	my $agentId = 0;
	my $subId = 0;
	my $publisherId = get_cookie("adsp" . $campaignId);
	if ($publisherId ne '')
	{
		$subId = get_cookie("adss" . $campaignId);
		$subId = 0 if ($subId eq '');

		set_cookie("adsp" . $campaignId, "", "+10M");
		set_cookie("adss" . $campaignId, "", "+10M");
		$bCookieMode = 1;
	} else { # try to get publisher from DB


		$agentId = DLookUp($db, "SELECT agentId FROM agents WHERE agent=" . to_sql($db, $agent, ""));
		if ($agentId == 0)
		{
			$r->header_out(Location => 'action?a=incorrect');
			return REDIRECT;
		}


		$st = $db->prepare("SELECT publisherId, subId FROM saleclicks" .
			" WHERE campaignId=" . to_sql($db, $campaignId, "Number") .
			" AND ip=" . to_sql($db, $ip, "") .
			" AND agentId=" . to_sql($db, $agentId, "Number") .
			" ORDER BY counter,done LIMIT 1"
		);
		$st->execute;
		if (my $row = $st->fetchrow_hashref() )
		{
			$publisherId = $row->{publisherId};
			$st->finish;
		} else {
			$st->finish;
			$r->header_out(Location => 'action?a=incorrect');
			return REDIRECT;
		}
	}


	# get campaign info ------------------------------------
	# and several checks ------------------------------------

	my $campaignTypeId = -1;
	my $price = 0;
	my $pricePub = 0;
	my $campaignAccount = 0;
	my $campaignStatus = -1;

	# get campaign info
	$st = $db->prepare("SELECT statusId,typeId,price,pricePub,account FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));
	$st->execute;
	if (my $row = $st->fetchrow_hashref() )
	{
		$campaignTypeId = $row->{typeId};
		$price = $row->{price};
		$pricePub = $row->{pricePub};
		$campaignAccount = $row->{account};
		$campaignStatus = $row->{statusId};
	}
	$st->finish;


	# campaign should be active or waiting for new values update
	if ($campaignStatus != 1 && $campaignStatus != 3)
	{
		$r->header_out(Location => 'action?a=incorrect');
		return REDIRECT;
	}

	# campaign should have #0 CPA-(per sale) type
	if ($campaignTypeId != 0)
	{
		$r->header_out(Location => 'action?a=incorrect');
		return REDIRECT;
	}

	# there should be the money on campaign account
	if ($campaignAccount < $price)
	{
		$r->header_out(Location => 'action?a=incorrect');
		return REDIRECT;
	}



	# get publisher info ------------------------------------

	my $publisherStatusId = -1;

	$st = $db->prepare("SELECT statusId FROM publishers WHERE publisherId=" . to_sql($db, $publisherId, "Number"));
	$st->execute;
	if (my $row = $st->fetchrow_hashref() )
	{
		$publisherStatusId = $row->{statusId};
	}
	$st->finish;


	# publisher should be active
	if ($publisherStatusId != 1)
	{
		$r->header_out(Location => 'action?a=incorrect');
		return REDIRECT;
	}

	# calc. spc. price for publisher
	my $priceSpec = DLookUp($db,
		"SELECT price FROM pub_cams" .
		" WHERE campaignId=" . to_sql($db, $campaignId, "Number") .
		" AND publisherId=" . to_sql($db, $publisherId, "Number"));
	$priceSpec = $pricePub if ($priceSpec eq "");
	


	# try to update already existed action record
	my $i = $db->do("UPDATE actions SET sales=sales+1 WHERE" .
			" campaignId=" . to_sql($db, $campaignId, "Number") .
			" AND publisherId=" . to_sql($db, $publisherId, "Number") .
			" AND done=curdate()" .
			" AND price=" . to_sql($db, $priceSpec, "Number") .
			" AND subId=" . to_sql($db, $subId, "Number"));

	# insert new action record if we have not such one
	if ($i == 0)
	{
		$db->do("INSERT INTO actions (sales,campaignId,publisherId,done,price,subId) VALUES (" .
			"1," .
			to_sql($db, $campaignId, "Number") . "," .
			to_sql($db, $publisherId, "Number") . "," .
			"curdate()," .
			to_sql($db, $priceSpec, "Number") . "," .
			to_sql($db, $subId, "Number") . ")");
	}

	# so we need to pay money ;-)
	$db->do("UPDATE campaigns SET account=account - " . to_sql($db, $price, "Number") .
		" WHERE campaignId=" . to_sql($db, $campaignId, "Number"));

	$db->do("UPDATE publishers SET account=account + " . to_sql($db, $priceSpec, "Number") .
		" WHERE publisherId=" . to_sql($db, $publisherId, "Number"));
#	$db->do("UPDATE publishers SET account=account + " . to_sql($db, $pricePub, "Number") .
#		" WHERE publisherId=" . to_sql($db, $publisherId, "Number"));


	# if there is not cookie sale action
	# then increment the counter in db
	if ($bCookieMode == 0)
	{
		$db->do("UPDATE saleclicks SET counter=counter + 1" .
			" WHERE campaignId=" . to_sql($db, $campaignId, "Number") .
			" AND publisherId=" . to_sql($db, $publisherId, "Number") .
			" AND ip=" . to_sql($db, $ip, "") .
			" AND agentId=" . to_sql($db, $agentId, "Number")
		);
	}


	# view the content
	$r->send_http_header("text/html");

    return OK;
}

1;
