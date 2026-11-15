package Ads::Admin::Advertisers;

#
# advertisers page of admin area
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

	my $db = $options->{db};
	get_block_params("aAdvertisers", $req);


	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/admin/advertisers.html", "main", $options);
	$Tpl->setvar("params", get_params());


	# parse the grid of advertisers
	grid($options, $db, $Tpl, "advertisers", 
		"SELECT a.advertiserId, a.email, a.passwd, a.name, a.company, s.title as status, a.registered FROM advertisers as a LEFT JOIN adv_statuses as s ON a.statusId=s.statusId",
		"SELECT count(*) as cnt FROM advertisers",
		{
			"advertiserId" => ["advertiserId", undef],
			"email" => ["email", undef],
			"passwd" => ["passwd", undef],
			"name" => ["name", undef],
			"company" => ["company", undef],
			"status" => ["status", undef],
			"registered" => ["registered", undef],
			"link" => ["link", "admin?p=advertiser&advertiserId="]
		},
		"admin",
		"advertiserId");




	HeaderFooter($Tpl);


#	$Tpl->setvar("sMessage", debug_params());

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");


	$r->send_http_header('text/html');
	print $main_block;

    return OK;
}

1;