#
# main mod-perl module for publisher web interface
# launcher
#

package Ads::Publisher;

use strict;
use Apache::Constants qw(:common);
use Apache::Request ();

use Ads::Template;
use Ads::Common;


use Ads::Publisher::Common;

# all pages of Publisher interface
use Ads::Publisher::Login;
use Ads::Publisher::Register;
use Ads::Publisher::Message;

use Ads::Publisher::Payments;
use Ads::Publisher::Campaigns;
use Ads::Publisher::Campaign;
use Ads::Publisher::Creative;
use Ads::Publisher::Preview;

use Ads::Publisher::RepCampaigns;

use Ads::Publisher::Supp;

sub handler {
	$options{r} = shift;;
	$options{req} = Apache::Request->new($options{r},
		POST_MAX => 10 * 1024 * 1024, # 10M max
		DISABLE_UPLOADS => 0 # is this for mod_perl_1 ?
	);

	my $status = $options{req}->parse();
#	return $status unless $status == OK;

	my $res = OK;

    %cookies = Apache::Cookie->fetch; # get cookies

	StartSession(); # start session

	%g_param_values = (); # remove all params from prev. request

	# connect to db
	$options{db} = DBI->connect($options{DB_CONN}, $options{DB_LOGIN}, $options{DB_PASSWD});

	# handle the request to specified page
	my $p = $options{req}->param("p");
	if ($p eq "login")
	{
		$res = Ads::Publisher::Login::process(\%options);
	} elsif ($p eq "register") {
		$res = Ads::Publisher::Register::process(\%options);
	} elsif ($p eq "message") {
		$res = Ads::Publisher::Message::process(\%options);
	} elsif ($p eq "payments") {
		$res = Ads::Publisher::Payments::process(\%options);
	} elsif ($p eq "campaigns") {
		$res = Ads::Publisher::Campaigns::process(\%options);
	} elsif ($p eq "campaign") {
		$res = Ads::Publisher::Campaign::process(\%options);
	} elsif ($p eq "creative") {
		$res = Ads::Publisher::Creative::process(\%options);
	} elsif ($p eq "preview") {
		$res = Ads::Publisher::Preview::process(\%options);
	} elsif ($p eq "supp") {
		$res = Ads::Publisher::Supp::process(\%options);
	} elsif ($p eq "rep_campaigns") {
		$res = Ads::Publisher::RepCampaigns::process(\%options);
	} else {
		$options{r}->send_http_header('text/html');
		print "No such page";
	}

	SaveSession();

	$options{db} = undef;
	$options{r} = undef;
	$options{req} = undef;

    return $res;
}

1;

