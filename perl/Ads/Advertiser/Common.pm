#
# common module for advertiser area
#
#

package Ads::Advertiser::Common;

use strict;
use Apache::Constants qw(:common);
use Apache::Request ();

#use vars qw(%g_params %g_depends %g_param_values);

use Ads::Template;
use Ads::Common;


BEGIN {
  use Exporter();
  use vars qw( @ISA @EXPORT @EXPORT_OK );
  @ISA = qw( Exporter );
  @EXPORT = qw( 

				&HeaderFooter
    );
}


# parser for header and footer of admin area
sub HeaderFooter {
	my ($Tpl) = @_;
	my $TplHeader = Ads::Template->new();
	$TplHeader->LoadTemplate($options{TemplatePath} . "/advertiser/header.html", "main", \%options);

	if (get_session("advertiserId") ne "")
	{
		$TplHeader->parse("mainMenu", "true");
	}
	else
	{
		$TplHeader->parse("loginMenu", "true");
	}
	$TplHeader->parse("main", "false");
	$Tpl->setvar("header", $TplHeader->getvar("main"));

	my $TplFooter = Ads::Template->new();
	$TplFooter->LoadTemplate($options{TemplatePath} . "/advertiser/footer.html", "main", \%options);
	$TplFooter->parse("main", "false");
	$Tpl->setvar("footer", $TplFooter->getvar("main"));
}


1;

