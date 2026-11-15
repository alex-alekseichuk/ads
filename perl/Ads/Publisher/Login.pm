package Ads::Publisher::Login;

#
# login page of Publisher interface
#



use strict;
use Apache::Constants qw(:common);
use Apache::Request ();
use Apache::Cookie ();

use Ads::Common ;
use Ads::Template ;

use Ads::Publisher::Common;


sub process {
    my $options = shift;

	my $r = $options->{r};
	my $req = $options->{req};

	my $cmd = $req->param("cmd");

	my $sMessage = "";
	my $db = $options->{db};


	# process logout action
	if ($cmd eq "logout")
	{
		set_session("publisherId", "");
		$sMessage = "You were logged out";
	}

	# process login action
	if ($cmd eq "login")
	{
		my $publisherId = 0;
		my $email = $req->param("email");

#		$sMessage = to_sql($db, $login, "");



		# check login		
		my $st = $db->prepare("SELECT publisherId, passwd, statusId FROM publishers WHERE email=" . to_sql($db, $email, ""));
		$st->execute;
		if (my ($publisherId_, $password, $statusId) = $st->fetchrow_array)
		{
			if ($password eq $req->param("password"))
			{
				if ($statusId == 0)
				{
					$sMessage = "Your account is not approved yet";
				} elsif ($statusId == 2) {
					$sMessage = "Your account is disabled for now";
				} else {
					$publisherId = $publisherId_;
				}
			} else {
				$sMessage = "Login/Password is incorrect";
			}
		} else {
			$sMessage = "Login/Password is incorrect";
		}
		$st->finish;

		# if logged in ok
		if ($publisherId != 0)		
		{
			set_session("publisherId", $publisherId);
			$r->header_out(Location => 'publisher?p=campaigns');
			return REDIRECT;
		}
	}

	# compose the page
	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/publisher/login.html", "main", $options);

	HeaderFooter($Tpl);

	$Tpl->setvar("sMessage", $sMessage);

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");

	$r->send_http_header('text/html');
	print $main_block;

    return OK;
}

1;
