package Ads::Admin::Admin;

#
# admin page of admin area
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

	my $sCheck = checkAdminGrants(4);
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
	get_block_params("aAdmin", $req);

	my $sql;

	my $adminId = get_param("adminId", 0);

	# delete admin
	if($adminId > 0 && $cmd eq "delete")
	{
		$db->do("DELETE FROM admin_grants WHERE adminId=" . to_sql($db, $adminId, "Number"));
		$db->do("DELETE FROM admins WHERE adminId=" . to_sql($db, $adminId, "Number"));
		$r->header_out(Location => 'admin?p=admins&mes=deleted');
		return REDIRECT;
	}

	my %fields = (
		login =>		{ title=>"Login", 						value=>"",	min=>2,	max=>32 },
		passwd =>		{ title=>"Password",					value=>"",	min=>5,	max=>32 }
	);



	# get values from http
	if ($cmd eq "create" || ($cmd eq "update" && $adminId > 0))
	{
		get_http(\%fields);

	}

	# create new action
	if ($cmd eq "create")
	{

		$sql = "INSERT INTO admins (" .
			sql_fields($db, \%fields) .
			") VALUES (" .
			sql_values($db, \%fields) .
			")";			

		my $res = $db->do($sql);

		if ($res != 0)		
		{
			$adminId = $db->{ q{mysql_insertid}};

			# add grants for this admin account
			my @grants = $req->param("granted");
			my $grantId;
			foreach $grantId (@grants)
			{
				$db->do("INSERT INTO admin_grants (adminId, grantId) VALUES (" . to_sql($db, $adminId, "Number") . "," . to_sql($db, $grantId, "Number") . ")");
			}

			$r->header_out(Location => "admin?p=admins&mes=created&" . get_params());
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
	}

	# update existed 
	if ($cmd eq "update" && $adminId > 0)
	{
		$sql = "UPDATE admins SET " .
			fields_to_sql($db, \%fields) .
			" WHERE adminId=" . to_sql($db, $adminId, "Number");

		my $res = $db->do($sql);



		if ($res != 0)		
		{
			# remove then inster actual grants for this admin account
			my @grants = $req->param("granted");
			my $grantId;
			$db->do("DELETE FROM admin_grants WHERE adminId=" . to_sql($db, $adminId, "Number"));
			foreach $grantId (@grants)
			{
				$db->do("INSERT INTO admin_grants (adminId, grantId) VALUES (" . to_sql($db, $adminId, "Number") . "," . to_sql($db, $grantId, "Number") . ")");
			}

			$r->header_out(Location => "admin?p=admins&mes=updated&" . get_params());
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
	}


	# get values from db fro existed record
	if($adminId > 0)
	{
		get_db($db, \%fields, "FROM admins WHERE adminId=" . to_sql($db, $adminId, "Number"));
	}


	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/admin/admin.html", "main", $options);
	$Tpl->setvar("params", get_params());


#$sMessage = debug_params();

	$Tpl->setvar("sMessage", $sMessage);


	$Tpl->setvar("adminId", $adminId);

	$Tpl->setvar("admin_checks", html_checks(\%fields, "admin"));

	parse_values($Tpl, \%fields);


	$Tpl->setvar("grantedOptions", DSelectOptions($db, "SELECT g.grantId, g.title FROM admin_grants AS a LEFT JOIN grants AS g ON g.grantId=a.grantId WHERE a.adminId=" . to_sql($db, $adminId, "Number"), 0));
	$Tpl->setvar("deniedOptions", DSelectOptions($db, "SELECT distinct g.grantId, g.title FROM grants AS g LEFT JOIN admin_grants AS a ON (g.grantId=a.grantId and a.adminId=" . to_sql($db, $adminId, "Number") . ") WHERE a.grantId is null"), 0);

	if ($adminId > 0)
	{
		$Tpl->setvar("sTitle", "Admin #" . $adminId);
		$Tpl->setvar("sCmd", "Update");
		$Tpl->setvar("cmd", "update");
		$Tpl->parse("bDelete");

	} else {
		$Tpl->setvar("sTitle", "New Admin");
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
