#
# the module for a grid
# it has grid() as main method to build the grid
#

package Ads::Grid;

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
				&grid
    );

}

use vars @EXPORT;

#
# main method to build the grid
# $options,
# $db
# $Tpl
# $name - name of the grid
# $_sql - sql to get items
# $sqlcount - sql to get number of items
# $fields - the set of fields for items, columns, sorting
# $link_page - the base link for pager and column sorter
# $_sort - sort field by default
#
sub grid {
	my ($options, $db, $Tpl, $name, $_sql, $sqlcount, $fields, $link_page, $_sort) = @_;
    my $m_nPerPage = 30;

	my $i;
	my $r = $options->{r};
	my $req = $options->{req};


	# get sort and sort_dir params
	# by default 'default_field' 'asc' used
	my $sortParam = $name . "Sort";
	my $sort = get_param($name . "Sort", $_sort);
	my $dir = get_param($name . "Dir", "");
	if (! exists $fields->{$sort})
	{
		$sort = $_sort;
	}
	elsif (defined $fields->{$sort}[1])
	{
		$sort = $_sort;
	}
	if ($sort ne "" && $dir ne "asc" && $dir ne "desc")
	{
		$dir = "asc";
	}

	# the base link for pager and column sorter
#	my $cur_page = $ENV{"SCRIPT_NAME"} . "?p=" . get_param("p", "") . "&";
	my $cur_page = $link_page . "?p=" . get_param("p", "") . "&";



	# get the total number of items
	my $n_n = DLookUp($db, $sqlcount);
	my $n_p;
	if ($n_n > 0) # if there is soem items
	{
		# calc. the number of pages
		if ($n_n eq "") {$n_n = 0;}
		$n_p = int(($n_n % $m_nPerPage > 0 ? 1 : 0) + ($n_n / $m_nPerPage));

		# get offset (page)
		my $nOffset = get_param($name . "Offset", 0);
		if ($nOffset < 0) {$nOffset = 0;}
		if ($nOffset >= $n_p) { $nOffset = 0; }

		# calc. last item
		my $nLast = ($nOffset + 1) * $m_nPerPage;
		$nLast = $n_n if $nLast > $n_n;

		# write info: from - to of whole_number
		$Tpl->setvar("info", ($nOffset  * $m_nPerPage + 1) . " - " . $nLast . " of " . $n_n);

		# write: First and Prev. in pager if it needs
		my $sOffset = $name . "Offset";
		if ($nOffset >= 10)
		{
			$Tpl->setvar("url", $cur_page . correct_param($sOffset, "0"));
			$Tpl->parse($name . "_first", "false");
			$Tpl->setvar("url", $cur_page . correct_param($sOffset, $nOffset - 10));
			$Tpl->parse($name . "_prev", "false");
		} else {
			$Tpl->setblockvar($name . "_first", "");
			$Tpl->setblockvar($name . "_prev", "");
		}


		# write: pages list in the pager
		my $n = int(($nOffset / 10) + 10);
		if ($n > $n_p) {$n = $n_p;}

		for ($i = int($nOffset / 10); $i < $n; $i++)
		{
			$Tpl->setvar("url", $cur_page . correct_param($sOffset, "" . $i));
			$Tpl->setvar("page", "" . ($i + 1));
			if ($i != $nOffset)
			{
				$Tpl->parse($name . "_link", "false");
				$Tpl->setblockvar($name . "_curpage", "");
			} else {
				$Tpl->setblockvar($name . "_link", "");
				$Tpl->parse($name . "_curpage", "false");
			}
			$Tpl->parse($name . "_page", "true");
		}

		# write: Next and Last in pager if it needs
		if (int($nOffset / 10) < int($n_p / 10))
		{
			$Tpl->setvar("url", $cur_page . correct_param($sOffset, ($nOffset + 10 > $n_p - 1) ? $n_p - 1 : $nOffset + 10 ));
			$Tpl->parse($name . "_next");
			$Tpl->setvar("url", $cur_page . correct_param($sOffset, $n_p - 1));
			$Tpl->parse($name . "_last");
		} else {
			$Tpl->setblockvar($name . "_next", "");
			$Tpl->setblockvar($name . "_last", "");
		}

		# write top pager, bottom pager
		$Tpl->parse($name . "_pager");
		$Tpl->setvar("pager2", $Tpl->getvar($name . "_pager"));
		$Tpl->setblockvar($name . "_noitems", "");

	
		# compose final sql, execute and write items

		my $sql = $_sql;

		if ($sort ne "")
		{
			$sql .= " ORDER BY " . $sort . " " . $dir;
		}
		$sql .= " LIMIT " . $m_nPerPage;
		if ($nOffset > 0)
		{
			$sql .= " OFFSET " . ($nOffset * $m_nPerPage);
		}
		my $st = $db->prepare($sql);
		$st->execute;
		while (my $row = $st->fetchrow_hashref() )
		{
			foreach $i (keys %$fields) # ($fields as $field)
			{
				if (! defined $fields->{$i}[1]) # $field[1] == null)
				{
					$Tpl->setvar($fields->{$i}[0], $row->{$fields->{$i}[0]});
				} else {
					$Tpl->setvar($fields->{$i}[0], $fields->{$i}[1]);
				}
			}
			$Tpl->parse($name . "_item", "true");
		}
		$st->finish;

	}	

	# no items at all
	if ($n_n == 0)
	{
		$Tpl->setvar("info", "");
		$Tpl->setvar($name . "_pager", "");
		$Tpl->setvar($name . "_pager2", "");
		$Tpl->parse($name . "_noitems");
	}

	# write columns sorters (headers)
	foreach $i (keys %$fields)
	{
		my $b = $name . "_sort_" . $fields->{$i}[0];
		if ($Tpl->blockexists($b))
		{
			if ($sort eq $fields->{$i}[0] && $dir eq "asc")
			{
				$Tpl->setvar("url", $cur_page . correct_param2($sortParam, $fields->{$i}[0], $name . "Dir", "desc"));
			} else {
				$Tpl->setvar("url", $cur_page . correct_param2($sortParam, $fields->{$i}[0], $name . "Dir", "asc"));
			}
			if ($sort eq $fields->{$i}[0] && $dir eq "desc")
			{
				$Tpl->parse($name . "_desc_" . $fields->{$i}[0]);
			} else {
				$Tpl->setvar($name . "_desc_" . $fields->{$i}[0], "");
			}
			if ($sort eq $fields->{$i}[0] && $dir eq "asc")
			{
				$Tpl->parse($name . "_asc_" . $fields->{$i}[0]);
			} else {
				$Tpl->setvar($name . "_asc_" . $fields->{$i}[0], "");
			}
			$Tpl->parse($b);
		}
	}

	$Tpl->parse($name); # put all together
	
#$Tpl->setvar("sMessage", "<hr>" . ($n_p) . "<hr>");

}



1;

