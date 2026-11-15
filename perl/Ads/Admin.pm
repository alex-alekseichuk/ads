#
# main mod-perl module for admin web interface
# launcher
#

package Ads::Admin;

use strict;
use Apache::Constants qw(:common);
use Apache::Request ();

use Ads::Template;
use Ads::Common;

use Ads::Admin::Common;

# all pages of admin interface
use Ads::Admin::Login;

use Ads::Admin::Advertisers;
use Ads::Admin::Advertiser;

use Ads::Admin::Campaign;
use Ads::Admin::CamPayments;

use Ads::Admin::CamPubPrice;

use Ads::Admin::Creative;
use Ads::Admin::Preview;

use Ads::Admin::Publishers;
use Ads::Admin::Publisher;
use Ads::Admin::PubCamPrice;
use Ads::Admin::PubPayments;

use Ads::Admin::Supp;

use Ads::Admin::Admins;
use Ads::Admin::Admin;

use Ads::Admin::Domains;
use Ads::Admin::Domain;

use Ads::Admin::Options;

use Ads::Admin::RepCampaigns;
use Ads::Admin::RepPublishers;
use Ads::Admin::RepPublisher;
use Ads::Admin::RepAdvertisers;
use Ads::Admin::RepAdvertiser;

use Ads::Admin::Message;


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
		$res = Ads::Admin::Login::process(\%options);
	} elsif ($p eq "advertisers") {
		$res = Ads::Admin::Advertisers::process(\%options);
	} elsif ($p eq "advertiser") {
		$res = Ads::Admin::Advertiser::process(\%options);
	} elsif ($p eq "campaign") {
		$res = Ads::Admin::Campaign::process(\%options);
	} elsif ($p eq "campubprice") {
		$res = Ads::Admin::CamPubPrice::process(\%options);
	} elsif ($p eq "cam_payments") {
		$res = Ads::Admin::CamPayments::process(\%options);
	} elsif ($p eq "creative") {
		$res = Ads::Admin::Creative::process(\%options);
	} elsif ($p eq "preview") {
		$res = Ads::Admin::Preview::process(\%options);
	} elsif ($p eq "publishers") {
		$res = Ads::Admin::Publishers::process(\%options);
	} elsif ($p eq "publisher") {
		$res = Ads::Admin::Publisher::process(\%options);
	} elsif ($p eq "pubcamprice") {
		$res = Ads::Admin::PubCamPrice::process(\%options);
	} elsif ($p eq "pub_payments") {
		$res = Ads::Admin::PubPayments::process(\%options);
	} elsif ($p eq "supp") {
		$res = Ads::Admin::Supp::process(\%options);
	} elsif ($p eq "admins") {
		$res = Ads::Admin::Admins::process(\%options);
	} elsif ($p eq "admin") {
		$res = Ads::Admin::Admin::process(\%options);
	} elsif ($p eq "domains") {
		$res = Ads::Admin::Domains::process(\%options);
	} elsif ($p eq "domain") {
		$res = Ads::Admin::Domain::process(\%options);
	} elsif ($p eq "options") {
		$res = Ads::Admin::Options::process(\%options);
	} elsif ($p eq "rep_campaigns") {
		$res = Ads::Admin::RepCampaigns::process(\%options);
	} elsif ($p eq "rep_publishers") {
		$res = Ads::Admin::RepPublishers::process(\%options);
	} elsif ($p eq "rep_publisher") {
		$res = Ads::Admin::RepPublisher::process(\%options);
	} elsif ($p eq "rep_advertisers") {
		$res = Ads::Admin::RepAdvertisers::process(\%options);
	} elsif ($p eq "rep_advertiser") {
		$res = Ads::Admin::RepAdvertiser::process(\%options);
	} elsif ($p eq "message") {
		$res = Ads::Admin::Message::process(\%options);
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

