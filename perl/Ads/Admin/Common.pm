#
# common module fro admin area
#
#

package Ads::Admin::Common;

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
				&checkAdminGrants
    );
}


# parser for header and footer of admin area
sub HeaderFooter {
	my ($Tpl) = @_;
	my $TplHeader = Ads::Template->new();
	$TplHeader->LoadTemplate($options{TemplatePath} . "/admin/header.html", "main", \%options);

	if (get_session("adminId") ne "")
	{
		$TplHeader->parse("mainMenu", "true");
	}
	$TplHeader->parse("main", "false");
	$Tpl->setvar("header", $TplHeader->getvar("main"));

	my $TplFooter = Ads::Template->new();
	$TplFooter->LoadTemplate($options{TemplatePath} . "/admin/footer.html", "main", \%options);
	$TplFooter->parse("main", "false");
	$Tpl->setvar("footer", $TplFooter->getvar("main"));
}


sub checkAdminGrants {
	my ($grantId) = @_;
	return "login"		if (get_session("adminId") eq "");
	return "denied"		if (0 == (get_session("grants") & (1 << ($grantId - 1))));
	return "";
}

1;

