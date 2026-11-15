package Ads::Admin::Home;

#
# this modules is not used for now
# maybe later
#

use strict;
use Apache::Constants qw(:common);
use Apache::Request ();
use Apache::Cookie ();
use DBI;


use Ads::Common ;
use Ads::Template ;
use Ads::Grid ;


sub process {
    my $options = shift;

	my $r = $options->{r};
	my $req = $options->{req};

	if (get_session("adminId") eq "")
	{
		$r->header_out(Location => 'admin?p=login&mes=login');
		return REDIRECT;
	}

	my $db = $options->{db};
	get_block_params("admins", $req);

	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/admin/home.html", "main", $options);


	grid($options, $db, $Tpl, "admins", 
		"SELECT adminId as adminid, login, passwd FROM admins",
		"SELECT count(*) as cnt FROM admins",
		{
			"adminid" => ["adminid", undef],
			"login" => ["login", undef],
			"passwd" => ["passwd", undef]
		},
		"adminid");

	HeaderFooter($Tpl);


#	$Tpl->setvar("sMessage", debug_params());

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");


	$r->send_http_header('text/html');
	print $main_block;

    return OK;
}

1;