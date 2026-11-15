package Ads::Publisher::Register;

#
# register page of publisher area
#


use strict;
use Apache::Constants qw(:common);
use Apache::Request ();
use Apache::Cookie ();

use Ads::Common;
use Ads::Template;
use Ads::Record;
use Ads::Grid;

use Ads::Publisher::Common;


sub process {
    my $options = shift;

	my $r = $options->{r};
	my $req = $options->{req};


	my $cmd = $req->param("cmd");

	my $sMessage = "";
	my $db = $options->{db};

	my $sql;
	my $st;



	my %fields = (
		email =>		{ title=>"Email", 						value=>"",	min=>7,	max=>120 },
		passwd =>		{ title=>"Password",					value=>"",	min=>5,	max=>32 },
		name =>			{ title=>"Name",						value=>"",	min=>2,	max=>64 },
		company =>		{ title=>"Company",						value=>"",	min=>2,	max=>64 },
		address1 =>		{ title=>"Address 1",					value=>"",	min=>2,	max=>128 },
		address2 =>		{ title=>"Address 2",					value=>"",	min=>0,	max=>128,	optional=>1 },
		city =>			{ title=>"City",						value=>"",	min=>2,	max=>64 },
		stateId=>		{ title=>"Sate",		type=>"int",	value=>0,	min=>0,	max=>1000,	nocheck=>1 },
		state =>		{ title=>"Non USA State",				value=>"",	min=>2,	max=>64,	nocheck=>1 },
		countryId =>	{ title=>"Country",		type=>"int",	value=>0,	min=>0,	max=>10000,	nocheck=>1 },
		zip =>			{ title=>"ZIP",							value=>"",	min=>2,	max=>32 },
		phone =>		{ title=>"Phone",						value=>"",	min=>2,	max=>64 },
		fax =>			{ title=>"Fax",							value=>"",	min=>2,	max=>64 },
		urlPub =>		{ title=>"Url",							value=>"",	min=>2,	max=>128 },
		registered =>	{ title=>"Registered",	type=>"plain",	value=>"",						noupdate=>1, nohttp=>1, nocheck=>1 }
	);



#$sMessage = fields_to_sql($db, \%fields);


	# create new publisher action
	if ($cmd eq "register")
	{
		get_http(\%fields);

		$fields{registered}{value} = "now()";

		$sql = "INSERT INTO publishers (" .
			sql_fields($db, \%fields) .
			") VALUES (" .
			sql_values($db, \%fields) .
			")";			

#$sMessage = $sql;
#=comment
		my $res = $db->do($sql);

		my $publisherId = $db->{ q{mysql_insertid}};

		if ($res != 0 && $publisherId > 0)
		{
			my $tplMail = Ads::Template->new();
			$tplMail->LoadTemplate($options->{TemplatePath} . "/email/pub_register.html", "main", $options);
			$tplMail->setvar("publisherId", $publisherId);
			$tplMail->setvar("email", $fields{email}{value});
			$tplMail->setvar("name", $fields{name}{value});
			$tplMail->setvar("ServerURL", $options->{ServerURL});
			$tplMail->parse("main", "false");
			send_email($options->{AdminEmail}, $options->{AdminEmail}, "Publisher Registration", $tplMail->getvar("main"), "text/html");

			$r->header_out(Location => "publisher?p=message&mes=registered&" . get_params());
			return REDIRECT;
		} else {
			$sMessage = "Server Error";
		}
#=cut
	}


	my $Tpl = Ads::Template->new();
	$Tpl->LoadTemplate($options->{TemplatePath} . "/publisher/register.html", "main", $options);
	$Tpl->setvar("params", get_params());


#$sMessage = debug_params();

	$Tpl->setvar("sMessage", $sMessage);



	$Tpl->setvar("publisher_checks", html_checks(\%fields, "publisher"));

	parse_values($Tpl, \%fields);

	$Tpl->setvar("statesOptions", DSelectOptions($db, "SELECT stateId, title FROM states", $fields{stateId}{value}));
	$Tpl->setvar("countriesOptions", DSelectOptions($db, "SELECT countryId, title FROM countries", $fields{countryId}{value}));



	HeaderFooter($Tpl);

	$Tpl->parse("main", "false");
	my $main_block = $Tpl->getvar("main");

	$r->send_http_header('text/html');
	print $main_block;

    return OK;
}

1;
