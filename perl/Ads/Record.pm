#
# the module for a record form
#

package Ads::Record;

use strict;
use Apache::Constants qw(:common);
use Apache::Request ();


use Ads::Template;
use Ads::Common;



BEGIN {
  use Exporter();
  use vars qw( @ISA @EXPORT @EXPORT_OK );
  @ISA = qw( Exporter );
  @EXPORT = qw( 
				&fields_to_sql
				&sql_fields
				&sql_values
				&get_http
				&get_db
				&parse_values
				&html_checks
    );

}

use vars @EXPORT;


sub field_title {
	my ($fields, $i) = @_;
	
	if (defined $fields->{$i}{title})
	{
		return $fields->{$i}{title};
	} else {
		return $i;
	}
}

# returns the list of pairs like name=value
# separated by ','
# ready to insert into sql-update
sub fields_to_sql {
	my ($db, $fields) = @_;
	my $ret = "";
	my $i;		
	foreach $i (keys %$fields)
	{
#		$ret .= "-" . $i . ":" . $fields->{$i}{value};
		if (! defined $fields->{$i}{noupdate})
		{
			$ret .= "," if $ret ne "";
			my $t = "";
			$t = "Number" if (defined $fields->{$i}{type} && ($fields->{$i}{type} eq "int" || $fields->{$i}{type} eq "float"));
			$t = "Plain" if (defined $fields->{$i}{type} && $fields->{$i}{type} eq "plain");
			$ret .= $i . "=" . to_sql($db, $fields->{$i}{value}, $t);
		}
	}
	return $ret;
}



# returns the list of fields names
# separated by ','
# ready to insert into sql-insert
sub sql_fields {
	my ($db, $fields) = @_;
	my $ret = "";
	my $i;		
	foreach $i (keys %$fields)
	{
#		$ret .= "-" . $i . ":" . $fields->{$i}{value};
		if (! defined $fields->{$i}{noinsert})
		{
			$ret .= "," if $ret ne "";
			$ret .= $i;
		}
	}
	return $ret;
}

# returns the list of fields values
# separated by ','
# ready to insert into sql-insert
sub sql_values {
	my ($db, $fields) = @_;
	my $ret = "";
	my $i;		
	foreach $i (keys %$fields)
	{
#		$ret .= "-" . $i . ":" . $fields->{$i}{value};
		if (! defined $fields->{$i}{noinsert})
		{
			$ret .= "," if $ret ne "";
			my $t = "";
			$t = "Number" if (defined $fields->{$i}{type} && ($fields->{$i}{type} eq "int" || $fields->{$i}{type} eq "float"));
			$t = "Plain" if (defined $fields->{$i}{type} && $fields->{$i}{type} eq "plain");
			$ret .= to_sql($db, $fields->{$i}{value}, $t);
		}
	}
	return $ret;
}

# get values of fields from http
sub get_http {
	my ($fields) = @_;
	my $i;		
	foreach $i (keys %$fields)
	{
		if (! defined $fields->{$i}{nohttp})
		{
			my $v = get_param($i, $fields->{$i}{value});

			if (! defined $fields->{$i}{nocheck})
			{
				if (defined $fields->{$i}{type} && ($fields->{$i}{type} eq "int" || $fields->{$i}{type} eq "float"))
				{
					if (defined $fields->{$i}{min} && (0 + $v) < $fields->{$i}{min})
					{
						$v = $fields->{$i}{min};
					}
					if (defined $fields->{$i}{max} && (0 + $v) > $fields->{$i}{max})
					{
						$v = $fields->{$i}{max};
					}
				} else {
					if (defined $fields->{$i}{max} && (0 + $v) > $fields->{$i}{max})
					{
						$v = substr($v, 0, $fields->{$i}{max});
					}
				}
			}
			$fields->{$i}{value} = $v;
		}
	}
}



# get values from db
# $sql is a sub-sql like "FROM table WHERE ..."
sub get_db {
	my ($db, $fields, $sqlFromWhere) = @_;
	my $i;

	my $fs = "";
	foreach $i (keys %$fields)
	{
		$fs .= "," if $fs ne "";
		$fs .= $i;
	}

	my $sql = "SELECT " . $fs . " " . $sqlFromWhere;
		
	my $st = $db->prepare($sql);
	$st->execute;
	my $r;
	$r = $st->fetchrow_hashref;

	foreach $i (keys %$fields)
	{
		if (! defined $fields->{$i}{nodb})
		{
			$fields->{$i}{value} = $r->{$i};
		}
	}
	$st->finish;
}



# parse all fields ?
sub parse_values {
	my ($Tpl, $fields) = @_;
	my $i;
	foreach $i (keys %$fields)
	{
		$Tpl->setvar($i, $fields->{$i}{value});
	}
}


# return the set of Javascript checks
# $form is the name of the <form>
sub html_checks {
	my ($fields, $form) = @_;
	my $i;
	my $ret = "";
	foreach $i (keys %$fields)
	{
		if (! defined $fields->{$i}{nocheck})
		{
			if (defined $fields->{$i}{type} && $fields->{$i}{type} eq "int")
			{
				$ret .= "sError += checkIntField(\"" .
					(defined $fields->{$i}{title} ? $fields->{$i}{title} : $i) .
					"\", document.forms[\"" . $form . "\"]." . $i . ".value," .
					(defined $fields->{$i}{min} ? $fields->{$i}{min} : "NaN") .
					"," .
					(defined $fields->{$i}{max} ? $fields->{$i}{max} : "NaN") .
					");"
			} elsif (defined $fields->{$i}{type} && $fields->{$i}{type} eq "float") {
				$ret .= "sError += checkFloatField(\"" .
					(defined $fields->{$i}{title} ? $fields->{$i}{title} : $i) .
					"\", document.forms[\"" . $form . "\"]." . $i . ".value," .
					(defined $fields->{$i}{min} ? $fields->{$i}{min} : "NaN") .
					"," .
					(defined $fields->{$i}{max} ? $fields->{$i}{max} : "NaN") .
					");"
			} else {
				$ret .= "sError += checkField(\"" .
					(defined $fields->{$i}{title} ? $fields->{$i}{title} : $i) .
					"\", document.forms[\"" . $form . "\"]." . $i . ".value," .
					((defined $fields->{$i}{optional} && $fields->{$i}{optional} == 1) ? "false" : "true") .
					"," .
					(defined $fields->{$i}{min} ? $fields->{$i}{min} : "NaN") .
					"," .
					(defined $fields->{$i}{max} ? $fields->{$i}{max} : "NaN") .
					");"
			}
		
			$ret .= "\n";
		}
	}
	return $ret;
}


1;

