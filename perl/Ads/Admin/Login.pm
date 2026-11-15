package Ads::Admin::Login;

#
# login page of admin interface
#



use strict;
use Apache::Constants qw(:common);
use Apache::Request ();
use Apache::Cookie ();
use DBI;

use Ads::Common ;
use Ads::Template ;

use Ads::Admin::Common;


sub process {
    my $options = shift;

	my $r = $options->{r};
	my $req = $options->{req};

	my $cmd = $req->param("cmd");

	my $db = $options->{db};


	my $sMessage = "";



	# process logout action
	if ($cmd eq "logout")
	{
		set_session("adminId", "");
		$sMessage = "You were logged out";
	}

	# process login action
	if ($cmd eq "login")
	{
		my $adminId = 0;
		my $login = $req->param("login");

#		$sMessage = to_sql($db, $login, "");



		# check login		
		my $st = $db->prepare("SELECT adminId, passwd FROM admins WHERE login=" . to_sql($db, $login, ""));
		$st->execute;
		if (my ($adminId_, $password) = $st->fetchrow_array)
		{
			if ($password eq $req->param("password"))
			{
				$adminId = $adminId_;
			}
		}
		$st->finish;

		# if logged in ok
		if ($adminId != 0)		
		{
			set_session("adminId", $adminId);

			my $grants = 0;
			my $st = $db->prepare("SELECT grantId FROM admin_grants WHERE adminId=" . to_sql($db, $adminId, "Number"));
			$st->execute;
			while (my ($grantId) = $st->fetchrow_array)
			{
				$grants |= (1 << ($grantId - 1));
			}
			$st->finish;

			set_session("grants", $grants);

			$r->header_out(Location => 'admin?p=advertisers');
			return REDIRECT;
		} else {
			$sMessage = "Login/Password is incorrect";
		}
	}

	# compose the page
	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/admin/login.html", "main", $options);

	HeaderFooter($Tpl);

	$Tpl->setvar("sMessage", $sMessage);

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");

	$r->send_http_header('text/html');
	print $main_block;

    return OK;
}

1;
