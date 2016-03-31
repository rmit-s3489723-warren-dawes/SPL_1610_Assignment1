#!/usr/bin/env perl
use strict;
use warnings;
use LWP::Simple;

open my $openfile, "emails.json" or die "Error opening file: $!\n";

my %kv_blocks;

my $line_num = 0;

# open file and read each line
while (<$openfile>)
{
	# debug: line number
	$line_num++;
	
	# remove leading/trailing white-spaces
	$_ =~ s/^\s+|\s+$//g;
	
	#print "$line_num:$_\n";
	
	# if a new block we prepare for key/value pairs
	if ($_ =~ m/{/)
	{
		next;
	}
	
	# if within the key/value portion - we preserve contents
	if ($_ =~ /^"/)
	{
		# debug: print string
		print "$_\n";		
		
		# new variables
		my $extract_key;
		my $extract_value;
		
		# if starting with double-quotes
		if($_ =~ /^"/)
		{
		    # extract any data within paired double-quotes
		    $_ =~ s/"(.*?)"//s;
		    
		    # assign key to extracted data ($1 from stack)
		    # http://stackoverflow.com/questions/1485046/how-can-i-extract-a-substring-enclosed-in-double-quotes-in-perl
		    $extract_key = $1;
		    
		    # same thing here - extract and assign
		    $_ =~ s/"(.*?)"//s;
		    $extract_value = $1;
		}
		
		# debug: perform web-request with timezone
		if ($extract_key eq "timeZone")
		{
			my $contents = get("http://api.timezonedb.com/?key=EHUCC69JBOJT&zone=$extract_value");
			print $contents;
		}
		
		print "->[$extract_key] = $extract_value\n";
		
		#my @kv_split = split(/:/, $_);
		#my $kv_combine;
		#
		#my $arraylen = $#kv_split;
		#	
		#if ($arraylen != 2)
		#{
		#	next;
		#}
		#
		#for (my $i = 0; $i <= $arraylen; $i++) {
		#	$kv_split[$i] =~ s/^\s+|\s+$//g; 	# remove whitespaces
		#	$kv_split[$i] =~ s/,+$//g;		# remove ending commas for values
		#}
		#
		#$kv_blocks{$kv_split[0]} = $kv_split[1];
		#
		#my $kv_key = $kv_split[0];
		#my $kv_value = $kv_blocks{$kv_split[0]};
		#
		#print "KV_HASH->$kv_key:$kv_value\n";
	}
}

close $openfile;