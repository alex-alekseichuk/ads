package Ads::Admin::Domains;

#
# domains page of admin area
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

	my $sCheck = checkAdminGrants(5);
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
	get_block_params("aDomains", $req);


	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/admin/domains.html", "main", $options);
	$Tpl->setvar("params", get_params());


	# parse the grid of domains
	grid($options, $db, $Tpl, "domains", 
		"SELECT domainId, domain FROM domains",
		"SELECT count(*) as cnt FROM domains",
		{
			"domainId" => ["domainId", undef],
			"domain" => ["domain", undef],
			"link" => ["link", "admin?p=domain&domainId="]
		},
		"admin",
		"domainId");



	HeaderFooter($Tpl);


#	$Tpl->setvar("sMessage", debug_params());

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");


	$r->send_http_header('text/html');
	print $main_block;

    return OK;
}

1;