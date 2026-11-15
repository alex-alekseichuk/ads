#
# test
#

package Ads::Test;

use strict;
use Apache::Constants qw(:common);
use Apache::Request;


sub handler {
	my $r = shift;;

	my $req = new Apache::Request($r);

	my $status = $req->parse();

	$r->send_http_header('text/html');
	print "Ok.";

	my $res = OK;

    return $res;
}

1;

