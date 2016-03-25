#!/usr/bin/env perl
use strict;
use warnings;

open my $openfile, "emails.json" or die "Error opening file: $!\n";

my %kv_blocks;

my $line_num = 0;

while (<$openfile>)
{
	$line_num++;
	
	$_ =~ s/^\s+|\s+$//g;
	
	#print "$line_num:$_\n";
	
	# if a new block we prepare for key/value pairs
	if ($_ =~ m/{/)
	{
		next;
	}
	
	# if within the key/value portion - we preserve contents
	if ($_ =~ m/^"/)
	{
		print "$_\n";		
		
		my $extract_key;
		my $extract_value;
		
		if($_ =~ /^"/)
		{
		    $_ =~ s/"(.*?)"//s;
		    $extract_key = $1;
		    
		    $_ =~ s/"(.*?)"//s;
		    $extract_value = $1;
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