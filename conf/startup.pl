
# make sure we are in a sane environment.
$ENV{MOD_PERL} or die "GATEWAY_INTERFACE not Perl!";

use strict;

use lib qw(/temp/ads/perl);

use Apache2 ();
use Apache::Status ();
use Apache::compat ();
use Apache ();

use ModPerl::Util ();
use ModPerl::Registry ();

use Apache::Reload ();
use Apache::Request ();
use Apache::Request::Redirect ();
use Apache::RequestRec ();
use Apache::RequestIO ();
use Apache::RequestUtil ();
use Apache::Server ();
use Apache::ServerUtil ();
use Apache::Connection ();
use Apache::Log ();
use Apache::Const -compile => ':common';
use APR::Const -compile => ':common';
use APR::Table ();


use Apache::DBI ();
#use Apache::AuthDBI;

# optional configuration for Apache::DBI.pm:

# choose debug output: 0 = off, 1 = quiet, 2 = chatty
#$Apache::DBI::DEBUG = 2;

# configure all connections which should be established during server startup.
# keep in mind, that if the connect does not succeeed, your server won't start
# until the connect times out (database dependent) !
# you may use a DSN with attribute settings specified within
#Apache::DBI->connect_on_init("dbi:driver(AutoCommit=>1):database", "userid", "passwd");
Apache::DBI->connect_on_init("dbi:mysql:database=ads;host=localhost", "ads_test", "test_password", {
		PrintError => 1, RaiseError => 1, AutoCommit =>1
	}
);

# configure the ping behavior of the persistent database connections
# you may NOT not use a DSN with attribute settings specified within
# $timeout = 0  -> always ping the database connection (default)
# $timeout < 0  -> never  ping the database connection
# $timeout > 0  -> ping the database connection only if the last access
#                  was more than timeout seconds before
#Apache::DBI->setPingTimeOut("dbi:driver:database", $timeout);


# optional configuration for Apache::AuthDBI.pm:

# choose debug output: 0 = off, 1 = quiet, 2 = chatty
$Apache::AuthDBI::DEBUG = 0;

# set lifetime in seconds for the entries in the cache
#Apache::AuthDBI->setCacheTime(0);

# set minimum time in seconds between two runs of the handler which cleans the cache
#Apache::AuthDBI->setCleanupTime(-1);

# use shared memory of given size for the cache
#Apache::AuthDBI->initIPC(50000);




1;