package Ads::Admin::Domain;

#
# domain page of admin area
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


	my $cmd = $req->param("cmd");

	my $sMessage = "";
	my $db = $options->{db};
	get_block_params("aDomain", $req);

	my $sql;

	my $domainId = get_param("domainId", 0);

	# delete domain
	if($domainId > 0 && $cmd eq "delete")
	{
		$db->do("DELETE FROM domains WHERE domainId=" . to_sql($db, $domainId, "Number"));
		$r->header_out(Location => 'admin?p=domains&mes=deleted');
		return REDIRECT;
	}

	my %fields = (
		domain =>		{ title=>"Domain", 						value=>"",	min=>4,	max=>64 }
	);



	# get values from http
	if ($cmd eq "create" || ($cmd eq "update" && $domainId > 0))
	{
		get_http(\%fields);

	}

	# create new action
	if ($cmd eq "create")
	{

		$sql = "INSERT INTO domains (" .
			sql_fields($db, \%fields) .
			") VALUES (" .
			sql_values($db, \%fields) .
			")";			

		my $res = $db->do($sql);

		if ($res != 0)		
		{
			$r->header_out(Location => "admin?p=domains&mes=created&" . get_params());
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
	}

	# update existed 
	if ($cmd eq "update" && $domainId > 0)
	{
		$sql = "UPDATE domains SET " .
			fields_to_sql($db, \%fields) .
			" WHERE domainId=" . to_sql($db, $domainId, "Number");

		my $res = $db->do($sql);

		if ($res != 0)		
		{
			$r->header_out(Location => "admin?p=domains&mes=updated&" . get_params());
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
	}


	# get values from db fro existed record
	if($domainId > 0)
	{
		get_db($db, \%fields, "FROM domains WHERE domainId=" . to_sql($db, $domainId, "Number"));
	}


	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/admin/domain.html", "main", $options);
	$Tpl->setvar("params", get_params());


#$sMessage = debug_params();

	$Tpl->setvar("sMessage", $sMessage);


	$Tpl->setvar("domainId", $domainId);

	$Tpl->setvar("domain_checks", html_checks(\%fields, "domain"));

	parse_values($Tpl, \%fields);


	if ($domainId > 0)
	{
		$Tpl->setvar("sTitle", "Domain #" . $domainId);
		$Tpl->setvar("sCmd", "Update");
		$Tpl->setvar("cmd", "update");
		$Tpl->parse("bDelete");

	} else {
		$Tpl->setvar("sTitle", "New Domain");
		$Tpl->setvar("sCmd", "Create");
		$Tpl->setvar("cmd", "create");
	}


	HeaderFooter($Tpl);

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");

	$r->send_http_header('text/html');
	print $main_block;

    return OK;
}

1;
