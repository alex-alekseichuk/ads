package Ads::Admin::Options;

#
# Options page of admin area
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

	my $sCheck = checkAdminGrants(6);
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

	my $cmd = $req->param("cmd");

	my $sMessage = "";
	my $db = $options->{db};
#	get_block_params("aOptions", $req);

	my $sql = "";
	my $st = undef;

	my $defaultDomainId = 1;

	# update options
	if($cmd eq "update")
	{
		$defaultDomainId = $req->param("defaultDomainId");
		$sql = "UPDATE options SET defaultDomainId=" . to_sql($db, $defaultDomainId, "Number");

		$db->do($sql);

		$sMessage = "Options updated";

#		$r->header_out(Location => 'admin?p=options&mes=updated');
#		return REDIRECT;
	}


	# get current options settings from DB
	$sql = "SELECT defaultDomainId FROM options";
	$st = $db->prepare($sql);
	$st->execute;
	($defaultDomainId) = $st->fetchrow_array;
	$st->finish;




	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/admin/options.html", "main", $options);
	$Tpl->setvar("params", get_params());


#$sMessage = debug_params();

	$Tpl->setvar("sMessage", $sMessage);


	$Tpl->setvar("domainOptions", DSelectOptions($db, "SELECT domainId, domain FROM domains", $defaultDomainId));



	HeaderFooter($Tpl);

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");

	$r->send_http_header('text/html');
	print $main_block;

    return OK;
}

1;
