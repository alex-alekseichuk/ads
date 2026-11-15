package Ads::Admin::Publishers;

#
# publishers page of admin area
#

use strict;
use Apache::Constants qw(:common);
use Apache::Request ();
use Apache::Cookie ();
use DBI;


use Ads::Common ;
use Ads::Template ;
use Ads::Grid ;

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

	my $db = $options->{db};
	get_block_params("aPublishers", $req);


	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/admin/publishers.html", "main", $options);
	$Tpl->setvar("params", get_params());


	# parse the grid of publishers
	grid($options, $db, $Tpl, "publishers", 
		"SELECT p.publisherId, p.email, p.passwd, p.name, p.company, s.title as status, p.registered, p.account FROM publishers as p LEFT JOIN pub_statuses as s ON p.statusId=s.statusId",
		"SELECT count(*) as cnt FROM publishers",
		{
			"publisherId" => ["publisherId", undef],
			"email" => ["email", undef],
			"passwd" => ["passwd", undef],
			"name" => ["name", undef],
			"company" => ["company", undef],
			"status" => ["status", undef],
			"account" => ["account", undef],
			"registered" => ["registered", undef],
			"link" => ["link", "admin?p=publisher&publisherId="]
		},
		"admin",
		"publisherId");



	HeaderFooter($Tpl);


#	$Tpl->setvar("sMessage", debug_params());

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");


	$r->send_http_header('text/html');
	print $main_block;

    return OK;
}

1;