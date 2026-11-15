#
# common module for whole ads project
#
#

package Ads::Common;

use strict;
use Apache::Constants qw(:common);
use Apache::Request ();
use MIME::Lite;

use vars qw(%options %SessionParamsHash_ %cookies %g_params %g_depends %g_param_values);

use Ads::Template;



BEGIN {
  use Exporter();
  use vars qw( @ISA @EXPORT @EXPORT_OK );
  @ISA = qw( Exporter );
  @EXPORT = qw( 
				%options
				%cookies

				&to_url
				&to_html
				&get_param

				&get_session
				&set_session
				&get_cookie
				&set_cookie
				&StartSession
				&SaveSession

				%g_params
				%g_depends
				%g_param_values

				&get_block_params
				&debug_params
				&get_params
				&correct_param
				&correct_param2

				&to_sql
				&DLookUp
				&DSelectOptions

				&send_email
    );

	# cookies received from browser (only received)
    %cookies = ();

	# parameters saved/loaded to/from session
	%SessionParamsHash_ = ();

	%options = (
		"PathToRoot"	=> "/Perl/Apache2/ads", # path to web root
		"ServerURL"		=> "http://localhost:8081/ads/",
		"ServerURI"		=> "/ads/",

		"HTTP_ROOT"		=> "/ads/",

		"DB_CONN"		=> "dbi:mysql:ads;host=localhost",
		"DB_LOGIN"		=> "",
		"DB_PASSWD"		=> "",

		"SMTP"			=> "127.0.0.1",
		"AdminEmail"	=> "admin@test.com",

		MaxCreativeLen => 51200, # max creative text len.

		SessionId => undef, # id of current session
		SessionTimeout => 30, # in minutes
		CleanSessionsRate => 100, # by 1/100 request we will delete old session files
		PathSeparator => "\\", # use another file separator for win. and *nix
		finalized => 0 # ? ? ?

	);

	$options{TemplatePath} = $options{PathToRoot}; # local path to folder with HTML templates
	$options{SessionsDir} = $options{PathToRoot} . "/sessions"; # local path to folder with session files
	$options{SuppDir} = $options{PathToRoot} . "/supp"; # local path to folder with supp files

	$options{ImgDir} = $options{PathToRoot} . "/images"; # local path to folder with creative images files (.jpg, .css, ...)
	$options{ImgURL} = $options{ServerURL} . "images/"; # base url for attached images in the server
	$options{ImgSubDir} = "images"; # just the name of the dir with images

#	$options{SessionParamsHash} = \%SessionParamsHash_;



	################################################################
	# parameters scheme
	#
	# each block (page) depends on several parameters

	# parameters of the blocks (pages)
	%g_params = (
		"aAdvertisers"	=> ["advertisersOffset", "advertisersSort", "advertisersDir"],
		"aAdvertiser"	=> ["advertiserId", "campaignsOffset", "campaignsSort", "campaignsDir"],
		"aCampaign"		=> ["campaignId", "creativesOffset", "creativesSort", "creativesDir", "pubpricesOffset", "pubpricesSort", "pubpricesDir"],
		"aCamPubPrice"	=> ["campaignId", "publisherId2"],
		"aCreative"		=> ["creativeId"],
		"aPublishers"	=> ["publishersOffset", "publishersSort", "publishersDir"],
		"aPublisher"	=> ["publisherId", "pubpricesOffset", "pubpricesSort", "pubpricesDir"],
		"aAdmins"		=> ["adminsOffset", "adminsSort", "adminsDir"],
		"aAdmin"		=> ["adminId"],
		"aDomains"		=> ["domainsOffset", "domainsSort", "domainsDir"],
		"aDomain"		=> ["domainId"],
		"aRepCampaigns"	=> ["campaignsOffset", "campaignsSort", "campaignsDir", "dFrom", "dTo"],
		"aRepPublishers"	=> ["publishersOffset", "publishersSort", "publishersDir", "dFrom", "dTo"],
		"aRepPublisher"	=> ["publisherId"],
		"aPubCamPrice"	=> ["campaignId2", "publisherId"],
		"aRepAdvetisers"	=> ["advetisersOffset", "advetisersSort", "advetisersDir", "dFrom", "dTo"],
		"aRepAdvetiser"	=> ["advetiserId"],

		"adCampaigns"	=> ["campaignsOffset", "campaignsSort", "campaignsDir"],
		"adCampaign"		=> ["campaignId", "creativesOffset", "creativesSort", "creativesDir"],
		"adCreative"		=> ["creativeId"],
		"adRepCampaigns"	=> ["campaignsOffset", "campaignsSort", "campaignsDir", "dFrom", "dTo"],

		"puCampaigns"	=> ["campaignsOffset", "campaignsSort", "campaignsDir"],
		"puCampaign"		=> ["campaignId", "creativesOffset", "creativesSort", "creativesDir"],
		"puCreative"		=> ["creativeId"],
		"puRepCampaigns"	=> ["campaignsOffset", "campaignsSort", "campaignsDir", "dFrom", "dTo"]

	);

	# depends between blocks
	%g_depends = (
		"aAdvertiser" => ["aAdvertisers"],
		"aCampaign" => ["aAdvertiser"],
		"aCamPubPrice" => ["aCampaign"],
		"aCreative" => ["aCampaign"],
		"aPublisher" => ["aPublishers"],
		"aPubCamPrice" => ["aPublisher"],
		"aAdmin" => ["aAdmins"],
		"aDomain" => ["aDomains"],
		"aPublisher" => ["aPublishers"],
		"aAdvertiser" => ["aAdvertisers"],

		"adCampaign" => ["adCampaigns"],
		"adCreative" => ["adCampaign"],

		"puCampaign" => ["puCampaigns"],
		"puCreative" => ["puCampaign"]
	);

	# actual parameters
	%g_param_values = ();

}

use vars @EXPORT;

# just get GET or POST parameter
sub get_param {
	my ($name, $default_value) = @_;
	my $val = "";
	$val = $options{req}->param($name);
	if ($val ne "")
	{
		return $val;
	} else {
		return $default_value;
	}
}


sub to_html {
  my $input_string = shift;
  if(defined($input_string)) {
    my %convert_hash = ( "<" => "&lt;", "&" => "&amp;", ">" => "&gt;", '"' => "&quot;" );
    $input_string =~ s/([<>&"])/$convert_hash{$1}/g;
  } else {
    $input_string = "";
  }
  return $input_string
}

sub to_url {
  my $input_string = shift;
  $input_string = defined($input_string) ? $input_string : ""; 
  $input_string =~ s/([^\w\.])/sprintf("%%%X", ord($1))/eg;
  $input_string =~ s/%20/+/g;
  return $input_string;
}






#######################################################################
# Session & Cookies Layer
#######################################################################

# call it beore use session
sub StartSession {
  %SessionParamsHash_ = ();
  $options{"SessionId"} = get_cookie("SessionID");
  if (!defined($options{SessionId}) || ($options{SessionId} eq "") || !(-e "$options{SessionsDir}/$options{SessionId}.tmp")) {
    if (!(-d $options{SessionsDir})) {
      mkdir($options{SessionsDir}, 0744);
    }
    $options{SessionId} = GenerateSessionID();
    open(SESSION_FILE, ">$options{SessionsDir}/$options{SessionId}.tmp");
    close(SESSION_FILE);
  } else {
    my $expiry_date = time() - (60 * $options{SessionTimeout});
    my $mtime = (stat("$options{SessionsDir}/$options{SessionId}.tmp"))[9];
    if($expiry_date > $mtime) {
      open(SESSION_FILE, ">$options{SessionsDir}/$options{SessionId}.tmp");
      close(SESSION_FILE);
    }
  }

#print "<hr>" . $options{SessionId} . "<hr>";

  set_cookie("SessionID", $options{SessionId}, "+1h");
  # read session file into hash
  my $slashcode = "\\\\" . ord("\\");
  my $coloncode = "\\\\" . ord(":");
  open(SESSION_FILE, "$options{SessionsDir}/$options{SessionId}.tmp");
  while(<SESSION_FILE>) {
    chomp;
    my ($type, $session_string) = /(\w):(.+)/g;
    my ($name, @values) = split(/:/, $session_string);
    $name   =~ s/$coloncode/:/;
    $name   =~ s/$slashcode/\\/;
    for ( my $i = 0; $i < @values; $i++ ) {
      $values[$i] =~ s/$coloncode/:/;
      $values[$i] =~ s/$slashcode/\\/;
    }
    if($type eq "a") {
 #     @{SessionParamsHash_{$name}} = @values;
    } else {
      $SessionParamsHash_{$name} = $values[0];
    }
  }
  close(SESSION_FILE);
  # remove expired session files
  if (rand() < (1/$options{CleanSessionsRate})) {
    DelExpiredSessions();
  }
}

sub DestroySession {
  $options{SessionParamsHash} = ();
}


sub GenerateSessionID {
  return time() . "_" . substr(rand(), 2);
}

sub get_session {
  my ($parameter_name) = shift;
  return (exists $SessionParamsHash_{$parameter_name} ? $SessionParamsHash_{$parameter_name} : "");
}

sub set_session {
  my ($parameter_name, $parameter_value) = @_;
  $SessionParamsHash_{$parameter_name} = $parameter_value;
}


# call it after session using
sub SaveSession {

  my $slashcode = "\\" . ord("\\");
  my $coloncode = "\\" . ord(":");
  open(SESSION_FILE, ">$options{SessionsDir}/$options{SessionId}.tmp");
  while(my ($key, $value) = each(%SessionParamsHash_)) {
    $key =~ s/\\/$slashcode/;
    $key =~ s/:/$coloncode/;
    if(ref($value) eq "ARRAY") {
#      print SESSION_FILE "a:" . $key;
#      foreach my $array_value (@{$value}) {      
#        $array_value =~ s/\\/$slashcode/;
#        $array_value =~ s/:/$coloncode/;
#        print SESSION_FILE ":" . $array_value;
#      }
#      print SESSION_FILE "\n";
    } elsif (defined($value)) {
      $value =~ s/\\/$slashcode/;
      $value =~ s/:/$coloncode/;
      print SESSION_FILE "v:" . $key . ":" . $value ."\n";
    }
  }
  close(SESSION_FILE);

}



sub get_cookie {
	my $cookie_name = shift;
    my $val = exists $cookies{$cookie_name} ? $cookies{$cookie_name}->value : '';
	return $val
}


sub set_cookie {
	my ( $name, $value, $exp_time ) = @_;

    my $c = Apache::Cookie->new(
         $options{r},
         -name    => $name,
         -value   => $value,
         -expires => $exp_time);
    
    # Add a Set-Cookie header to the outgoing headers table
    $c->bake;
}


# ! ! ! needs to rewrite to close sessions in the way that doesn't make the system so busy ! ! !
sub DelExpiredSessions {
  my $expiry_date = time() - (60 * $options{SessionTimeout});
  opendir(SESSION_TEMP_DIR, $options{TempSessionDir});
  my (@sessions) = readdir(SESSION_TEMP_DIR); 
  my ($file_name, $create_date);
  for $file_name (@sessions) {
    my $mtime = (stat($options{TempSessionDir} . $options{PathSeparator} . $file_name))[9];
    if ($expiry_date > $mtime && $file_name !~ /^\./) {
      unlink ($options{TempSessionDir} . $options{PathSeparator} . $file_name);
    }
  }
  closedir(SESSION_TEMP_DIR);
}




#######################################################################
# DB Layer
#######################################################################

# prepare some value to insert into sql statement
sub to_sql {
    my ($db, $Value, $ValueType) = @_;
	if ($ValueType eq "Plain")
	{
		return $Value;
	}
    if ( length($Value) ||  length($ValueType) == 0) {
        if ( $ValueType eq "Number" || $ValueType eq "Float" ) {
            #return ( 0 + replace($Value, ",", ".") );
            return 0 + $Value;
        } elsif ( $ValueType eq "Date" ) {
            #if (ref($Value) eq "ARRAY") {
            #    $Value = CCFormatDate($Value, @{$self->{DateFormat}});
            #}
            return "#$Value#";
        } else {
			if (length($Value))
			{
	            return $db->quote($Value);
			} else {
				return "''";
			}
        }
    } else {
		return "NULL";
    }
}

# just get some value from db by specified sql
sub DLookUp {
	my ($db, $sql) = @_;
	my $st = $db->prepare($sql);
	$st->execute;
	my $ret = "";
	if (my ($v) = $st->fetchrow_array)
	{
		$ret = $v;
	}
	$st->finish;
	return $ret;
}

# compose <select> options by sql and selected value
sub DSelectOptions {
	my ($db, $sql, $selected) = @_;
	my $st = $db->prepare($sql);
	$st->execute;
	my $ret = "";
	while (my ($v, $s) = $st->fetchrow_array)
	{
		$ret .= "<option value=\"" . $v . "\"" . ($v eq $selected ? " selected" : "") . ">" . $s. "</option>\n";
	}
	$st->finish;
	return $ret;
}


#######################################################################
# Params Layer
#######################################################################

# call it before paramters using and templates loading
sub get_block_params {
	my ($name, $req) = @_;
	my $key;
	if (exists $g_params{$name})
	{
		my $params = $g_params{$name};
		foreach $key (@$params)
		{
			if (! exists $g_param_values{$key})
			{
				$g_param_values{$key} = $req->param($key);
			}
		}
	}
	if (exists $g_depends{$name})
	{
		my $params2 = $g_depends{$name};
		foreach $key (@$params2)
		{
			&get_block_params($key, $req);
		}
	}
}	
sub debug_params { # just return current actual parameters
	my $sRet = "";
	my $key;
	foreach $key (keys %g_param_values)
	{
		$sRet .= $key . "=" . $g_param_values{$key} . "<br>";
	}
	return $sRet;
}
sub get_params { # just compose url-like string of actual paramteres
	my $sRet = "";
	my $key;
	foreach $key (keys %g_param_values)
	{
		if ($sRet ne "")
		{
			$sRet .= "\&";
		}
		$sRet .= $key . "=" . $g_param_values{$key};
	}
	return $sRet;
}	
sub correct_param { # compose url-like string but add/change specified parameter
	my ($name, $new_value) = @_;
	my $sRet = "";
	my $key;
	foreach $key (keys %g_param_values)
	{
		if ($key ne "")
		{
			if ($sRet ne "")
			{
				$sRet .= "\&";
			}
			$sRet .= $key . "=" . ($key eq $name ? $new_value : $g_param_values{$key});
		}
	}
	if (! exists $g_param_values{$name})
	{
		if ($sRet ne "")
		{
			$sRet .= "\&";
		}
		$sRet .= $name . "=" . $new_value;
	}
	return $sRet;
}	
sub correct_param2 { # compose url-like string but add/change 2 specified parameters
	my ($name, $new_value, $name2, $new_value2) = @_;
	my $sRet = "";
	my $key;
	foreach $key (keys %g_param_values)
	{
		if ($key ne "")
		{
			if ($sRet ne "")
			{
				$sRet .= "\&";
			}
			$sRet .= $key . "=" . ($key eq $name ? $new_value : ($key eq $name2 ? $new_value2 : $g_param_values{$key}));
		}
	}
	if (! exists $g_param_values{$name})
	{
		if ($sRet ne "")
		{
			$sRet .= "\&";
		}
		$sRet .= $name . "=" . $new_value;
	}
	if (! exists $g_param_values{$name2})
	{
		if ($sRet ne "")
		{
			$sRet .= "\&";
		}
		$sRet .= $name2 . "=" . $new_value2;
	}
	return $sRet;
}	




# email function
sub send_email
{
	# get incoming parameters
	my ($to, $from, $subject, $message, $type) = @_;

	if ($type eq "")
	{
		$type = "text/plain";
	}

	# create a new message
	my $msg = MIME::Lite->new(
		From => $from,
		To => $to,
		Subject => $subject,
		Data => $message,
	Type => $type
	);

	# send the email
	MIME::Lite->send('smtp', $options{SMTP}, Timeout => 60);
	$msg->send();
} 



1;

