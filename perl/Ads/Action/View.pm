package Ads::Action::View;

#
# View action
# used CPC-(per click) and CPA-(per sale) and CPM-(per 1000 views) campaigns
# so, all campaigns use it
#
# it's just the url like: http://server/proc/action?a=v&...
# it's working in 2 modes: 1x1 pixel and view mode
# view mode: (both count then view)
#	publisher may use it just like url on his site:
#	<a href="http://adsbucks.com/ads/action?a=v&c=1&p=1&r=1&v=1&"
#	v=1 paramter should be in the url
# 1x1 picel mode: (just count; nothing view)
# 	that publisher should insert into creative page downloaded from the site
# 	it's 1x1 pixel code: <img width="1" height="1" src="..." />
# 	it should not show the content. it's not a viewer. it's just a counter of views.
#
# a=v - view action
# c - campaignId
# p - publisherId
# s - subId
# r - creativeId
# v - 1-view mode, else-no view just count used in 1x1 pixel



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
	my $sql = "";
	my $st = undef;



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

	my $creativeId = get_param("r", 0);
	if ($creativeId == 0)
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

	# get campaign info
	$st = $db->prepare("SELECT statusId,typeId,priceCPM,pricePubCPM,account FROM campaigns WHERE campaignId=" . to_sql($db, $campaignId, "Number"));
	$st->execute;
	if (my $row = $st->fetchrow_hashref() )
	{
		$campaignTypeId = $row->{typeId};
		$price = $row->{priceCPM};
		$pricePub = $row->{pricePubCPM};
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

=comment
	# ! now we record it for all campaigns !
	# campaign should have #2 CPM-(per 1000 views) type
	if ($campaignTypeId != 2)
	{
		$r->header_out(Location => 'action?a=incorrect');
		return REDIRECT;
	}
=cut

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


	# get creative info ---------------------------

	my $creativeTypeId = -1;
	my $creativeStatusId = -1;
	my $creativeText = "";
	$st = $db->prepare("SELECT statusId,typeId,body FROM creatives WHERE creativeId=" . to_sql($db, $creativeId, "Number"));
	$st->execute;
	if (my $row = $st->fetchrow_hashref() )
	{
		$creativeTypeId = $row->{typeId};
		$creativeStatusId = $row->{statusId};
		$creativeText = $row->{body};
	}
	$st->finish;

	# unknown creative
	if ($creativeTypeId == -1)
	{
		$r->header_out(Location => 'action?a=incorrect');
		return REDIRECT;
	}

	# creative StatusId should be active or waiting for new values update
	if ($creativeStatusId != 1 && $creativeStatusId != 3)
	{
		$r->header_out(Location => 'action?a=incorrect');
		return REDIRECT;
	}


	# calc. spec. price for publisher
	my $priceSpec = 0;
	if ($campaignTypeId == 2)
	{
		$priceSpec = DLookUp($db,
			"SELECT priceCPM FROM pub_cams" .
			" WHERE campaignId=" . to_sql($db, $campaignId, "Number") .
			" AND publisherId=" . to_sql($db, $publisherId, "Number"));
		$priceSpec = $pricePub if ($priceSpec eq "");

		# try to update already existed action record
		my $i = $db->do("UPDATE actions SET views=views+1 WHERE" .
			" campaignId=" . to_sql($db, $campaignId, "Number") .
			" AND publisherId=" . to_sql($db, $publisherId, "Number") .
			" AND done=curdate()" .
			" AND price=" . to_sql($db, $priceSpec, "Number") .
			" AND subId=" . to_sql($db, $subId, "Number"));

		# insert new action record if we have not such one
		if ($i == 0)
		{
			$db->do("INSERT INTO actions (views,campaignId,publisherId,done,price,subId) VALUES (" .
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

	} else { # this is just count action without payment for it

		# try to update already existed action record
		my $i = $db->do("UPDATE actions SET views=views+1 WHERE" .
			" campaignId=" . to_sql($db, $campaignId, "Number") .
			" AND publisherId=" . to_sql($db, $publisherId, "Number") .
			" AND done=curdate()" .
			" AND subId=" . to_sql($db, $subId, "Number"));

		# insert new action record if we have not such one
		if ($i == 0)
		{
			$db->do("INSERT INTO actions (views,campaignId,publisherId,done,subId) VALUES (" .
				"1," .
				to_sql($db, $campaignId, "Number") . "," .
				to_sql($db, $publisherId, "Number") . "," .
				"curdate()," .
				to_sql($db, $subId, "Number") . ")");
		}

	}



	my $bView = get_param("v", 0);
	if ($bView == 1)
	{
		$r->send_http_header($creativeTypeId == 1 ? "text/plain" : "text/html");
	
		if ($creativeTypeId == 2) # if it's HTML content
		{

			$sql = "SELECT name FROM cre_imgs WHERE creativeId=" . to_sql($db, $creativeId, "Number");
			$st = $db->prepare($sql);
			$st->execute;
			while (my $row = $st->fetchrow_hashref() )
			{
				my $name = $row->{name};
				my $newName = $options{ImgURL} . $creativeId . "_" . $name;
				$creativeText =~ s/$name/$newName/ge;
			}
			$st->finish;
		}
		print $creativeText;
	} else {
		# view the content
		$r->send_http_header("text/html");
	}
    return OK;
}

1;
