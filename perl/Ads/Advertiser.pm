#
# main mod-perl module for advertiser web interface
# launcher
#

package Ads::Advertiser;

use strict;
use Apache::Constants qw(:common);
use Apache::Request ();

use Ads::Template;
use Ads::Common;

use Ads::Advertiser::Common;

use Ads::Advertiser::Login;
use Ads::Advertiser::Register;
use Ads::Advertiser::Message;

use Ads::Advertiser::Campaigns;
use Ads::Advertiser::Campaign;
use Ads::Advertiser::CamPayments;
use Ads::Advertiser::Creative;
use Ads::Advertiser::Preview;

use Ads::Advertiser::RepCampaigns;

use Ads::Advertiser::Supp;


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
		$res = Ads::Advertiser::Login::process(\%options);
	} elsif ($p eq "register") {
		$res = Ads::Advertiser::Register::process(\%options);
	} elsif ($p eq "message") {
		$res = Ads::Advertiser::Message::process(\%options);
	} elsif ($p eq "campaigns") {
		$res = Ads::Advertiser::Campaigns::process(\%options);
	} elsif ($p eq "campaign") {
		$res = Ads::Advertiser::Campaign::process(\%options);
	} elsif ($p eq "cam_payments") {
		$res = Ads::Advertiser::CamPayments::process(\%options);
	} elsif ($p eq "creative") {
		$res = Ads::Advertiser::Creative::process(\%options);
	} elsif ($p eq "preview") {
		$res = Ads::Advertiser::Preview::process(\%options);
	} elsif ($p eq "rep_campaigns") {
		$res = Ads::Advertiser::RepCampaigns::process(\%options);
	} elsif ($p eq "supp") {
		$res = Ads::Advertiser::Supp::process(\%options);
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

