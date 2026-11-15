package Ads::Action::Click;

#
# Click action
# used CPC-(per click) and CPA-(per sale) and CPM-(per 1000 views) campaigns
# so, all campaigns use it
#
# it should count the click and then redirect to some url
# campaigns.urlActual like url-template with parameters:
#    E.g.: http://server.com/script?campaign={c}&publisher={p}&subId={s}
#
# a=c - click action
# c - campaignId
# p - publisherId
# s - subId
#
#
# e.g.
# http://localhost:8081/ads/proc/action?a=c&c=9&p=3&s=77
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

	my $publisherId = get_param("p", 0);
	if ($publisherId == 0)
	{
		$r->header_out(Location => 'action?a=incorrect');
		return REDIRECT;
	}

	my $campaignId = get_param("c", 0);
	if ($campaignId == 0)
	{
		$r->header_out(Location => 'action?a=incorrect');
		return REDIRECT;
	}


	my $subId = get_param("s", 0);




	# get campaign info ------------------------------------
	# and several checks ------------------------------------



	my $campaignTypeId = -1;
	my $price = 0;
	my $pricePub = 0;
	my $campaignAccount = 0;
	my $campaignStatus = -1;
	my $urlActual = "";

	# get campaign info
	$st = $db->prepare("SELECT urlActual,statusId,typeId,price,pricePub,account FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));
	$st->execute;
	if (my $row = $st->fetchrow_hashref() )
	{
		$campaignTypeId = $row->{typeId};
		$price = $row->{price};
		$pricePub = $row->{pricePub};
		$campaignAccount = $row->{account};
		$campaignStatus = $row->{statusId};
		$urlActual = $row->{urlActual};
	}
	$st->finish;

	# campaign should be active or waiting for new values update
	if ($campaignStatus != 1 && $campaignStatus != 3)
	{
		$r->header_out(Location => 'action?a=incorrect');
		return REDIRECT;
	}

=comment
	# ! for now it's for all campaigns !
	# campaign should have #0 CPA (pay per sale) or #1 CPC (pay per click) type
	if ($campaignTypeId != 0 && $campaignTypeId != 1)
	{
		$r->header_out(Location => 'action?a=incorrect');
		return REDIRECT;
	}
=cut


	# if it's per click campaign	
	if ($campaignTypeId == 1)
	{
		# there should be the money on campaign account
		if ($campaignAccount < $price)
		{
			$r->header_out(Location => 'action?a=incorrect');
			return REDIRECT;
		}
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


	if ($urlActual eq "")
	{
		$r->header_out(Location => 'action?a=incorrect');
		return REDIRECT;
	}


	# if it's per click campaign	
	if ($campaignTypeId == 1)
	{
		# calc. spec. price for publisher
		my $priceSpec = DLookUp($db,
			"SELECT price FROM pub_cams" .
			" WHERE campaignId=" . to_sql($db, $campaignId, "Number") .
			" AND publisherId=" . to_sql($db, $publisherId, "Number"));
		$priceSpec = $pricePub if ($priceSpec eq "");


		# try to update already existed action record
		my $i = $db->do("UPDATE actions SET clicks=clicks+1 WHERE" .
			" campaignId=" . to_sql($db, $campaignId, "Number") .
			" AND publisherId=" . to_sql($db, $publisherId, "Number") .
			" AND done=curdate()" .
			" AND price=" . to_sql($db, $priceSpec, "Number") .
			" AND subId=" . to_sql($db, $subId, "Number"));


		# insert new action record if we have not such one
		if ($i == 0)
		{
			$db->do("INSERT INTO actions (clicks,campaignId,publisherId,done,price,subId) VALUES (" .
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

	} else {

		# try to update already existed action record
		my $i = $db->do("UPDATE actions SET clicks=clicks+1 WHERE" .
			" campaignId=" . to_sql($db, $campaignId, "Number") .
			" AND publisherId=" . to_sql($db, $publisherId, "Number") .
			" AND done=curdate()" .
			" AND subId=" . to_sql($db, $subId, "Number"));

		# insert new action record if we have not such one
		if ($i == 0)
		{
			$db->do("INSERT INTO actions (clicks,campaignId,publisherId,done,subId) VALUES (" .
				"1," .
				to_sql($db, $campaignId, "Number") . "," .
				to_sql($db, $publisherId, "Number") . "," .
				"curdate()," .
				to_sql($db, $subId, "Number") . ")");
		}

	}


	# for #0 CPA-(per sale) type campaign
	if ($campaignTypeId == 0)
	{
		my $ip = $r->connection->remote_ip;
		my $agent = $r->header_in("User-Agent");

		my $agentId = DLookUp($db, "SELECT agentId FROM agents WHERE agent=" . to_sql($db, $agent, ""));
		if ($agentId == 0)
		{
			$db->do("INSERT INTO agents (agent) VALUES (" .
				to_sql($db, $agent, "") .
				")");
			$agentId = $db->{ q{mysql_insertid}};
		}

		$db->do("INSERT INTO saleclicks (campaignId,publisherId,ip,agentId,subId,done,counter) VALUES (" .
			to_sql($db, $campaignId, "Number") . "," .
			to_sql($db, $publisherId, "Number") . "," .
			to_sql($db, $ip, "") . "," .
			to_sql($db, $agentId, "Number") . "," .
			to_sql($db, $subId, "Number") . "," .
			"curdate(),0" .
			")");
	}


	$urlActual =~ s/\{c\}/$campaignId/ge;
	$urlActual =~ s/\{p\}/$publisherId/ge;
	$urlActual =~ s/\{s\}/$subId/ge;


	set_cookie("adsp" . $campaignId, $publisherId, "+10M");
	set_cookie("adss" . $campaignId, $subId, "+10M");

		

	$r->send_http_header("text/html");
	print "<head><meta http-equiv=\"refresh\" content=\"0; URL=" . $urlActual . "\"></head>";
	return OK;


}

1;
