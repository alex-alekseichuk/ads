package Ads::Admin::PubPayments;

#
# payments of publisher
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

	my $sCheck = checkAdminGrants(2);
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

	# if publisher is not choosed
	my $publisherId = get_param("publisherId", 0);
	if ($publisherId == 0)
	{
		$r->header_out(Location => 'admin?p=publishers');
		return REDIRECT;
	}


	my $cmd = $req->param("cmd");

	my $sMessage = "";
	my $db = $options->{db};
	get_block_params("aPublisher", $req);

	my $sql;


	my %fields = (
		amount =>		{ title=>"Amount",		type=>"float",	value=>0,	min=>0,				noupdate=>1 },
		notes =>		{ title=>"Notes",						value=>"",	min=>5,	max=>255,	optional=>1 },
		publisherId =>	{ 	type=>"plain",	value=>to_sql($db, $publisherId, "Number"), 		noupdate=>1, nohttp=>1, nocheck=>1 },
		paid =>			{ 	type=>"plain",	value=>"now()",										noupdate=>1, nohttp=>1, nocheck=>1 }
	);



#$sMessage = fields_to_sql($db, \%fields);



	# get values from http
	if ($cmd eq "create")
	{
		get_http(\%fields);
	}

	# create new action
	if ($cmd eq "create")
	{
		$sql = "INSERT INTO pub_payments (" .
			sql_fields($db, \%fields) .
			") VALUES (" .
			sql_values($db, \%fields) .
			")";			

		my $res = $db->do($sql);

		if ($res != 0)
		{
			$sql = "UPDATE publishers SET account=account - " . to_sql($db, $fields{amount}->{value}, "Number") . " WHERE publisherId=" . to_sql($db, $publisherId, "Number");
			$res = $db->do($sql);
		}

		if ($res == 0)
		{
			$sMessage = "Server Error";
		}
	}

	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/admin/pub_payments.html", "main", $options);
	$Tpl->setvar("params", get_params());


#$sMessage = debug_params();

	$Tpl->setvar("sMessage", $sMessage);

	$Tpl->setvar("publisherId", $publisherId);
	$Tpl->setvar("sTitle", "Publisher #" . $publisherId);

	$Tpl->setvar("payment_checks", html_checks(\%fields, "payment"));

	parse_values($Tpl, \%fields);

	$Tpl->parse("bPublisher", "false");
	$Tpl->parse("bPayment", "false");
		

	# parse the grid of payments
	grid($options, $db, $Tpl, "payments", 
		"SELECT amount, paid, notes FROM pub_payments WHERE publisherId=" . to_sql($db, $publisherId, "Number"),
		"SELECT count(*) as cnt FROM pub_payments WHERE publisherId=" . to_sql($db, $publisherId, "Number"),
		{
			"amount" => ["amount", undef],
			"paid" => ["paid", undef],
			"notes" => ["notes", undef]
		},
		"admin",
		"paid");


	HeaderFooter($Tpl);

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");

	$r->send_http_header('text/html');
	print $main_block;


    return OK;
}

1;
