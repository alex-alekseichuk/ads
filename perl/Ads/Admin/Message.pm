package Ads::Admin::Message;

#
# message page of Admin interface
#



use strict;
use Apache::Constants qw(:common);
use Apache::Request ();
use Apache::Cookie ();

use Ads::Common ;
use Ads::Template ;

use Ads::Admin::Common;


sub process {
    my $options = shift;

	my $r = $options->{r};
	my $req = $options->{req};

	my $mes = $req->param("mes");

	my $sMessage = "";
	my $db = $options->{db};


	if ($mes eq "denied")
	{
		$sMessage = "You have not privileges to access this area.";
	}

	# compose the page
	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/admin/message.html", "main", $options);

	HeaderFooter($Tpl);

	$Tpl->setvar("sMessage", $sMessage);

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");

	$r->send_http_header('text/html');
	print $main_block;

    return OK;
}

1;
