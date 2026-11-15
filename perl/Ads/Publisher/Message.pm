package Ads::Publisher::Message;

#
# message page of Publisher interface
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

	my $mes = $req->param("mes");

	my $sMessage = "";
	my $db = $options->{db};


	if ($mes eq "registered")
	{
		$sMessage = "Your registration information will be checked soon.<br>We'll email the confirmation to provided Email address.";
	}

	# compose the page
	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/publisher/message.html", "main", $options);

	HeaderFooter($Tpl);

	$Tpl->setvar("sMessage", $sMessage);

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");

	$r->send_http_header('text/html');
	print $main_block;

    return OK;
}

1;
