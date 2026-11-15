#
# Actions mod-perl module
# launcher
#

package Ads::Action;

use strict;
use Apache::Constants qw(:common);
use Apache::Request ();

use Ads::Template;
use Ads::Common;

#use Ads::Admin::Common;

# all pages of admin interface
use Ads::Action::Click;
use Ads::Action::View;
use Ads::Action::Sale;


sub handler {
	$options{r} = shift;;
	$options{req} = Apache::Request->new($options{r});

	my $status = $options{req}->parse();

	my $res = OK;

    %cookies = Apache::Cookie->fetch; # get cookies

	# connect to db
	$options{db} = DBI->connect($options{DB_CONN}, $options{DB_LOGIN}, $options{DB_PASSWD});

	# type of action v-view, c-click, s-sale
	# view by default
	my $a = get_param("a", "v");
	

	if ($a eq "v")
	{
		$res = Ads::Action::View::process(\%options); # view
	} elsif ($a eq "c") {
		$res = Ads::Action::Click::process(\%options); # click
	} elsif ($a eq "s") {
		$res = Ads::Action::Sale::process(\%options); # sale
	} else {
		$options{r}->send_http_header('text/html');
		print "Incorrect action: " . $a;
	}

	$options{db} = undef;
	$options{r} = undef;
	$options{req} = undef;

    return $res;
}

1;

