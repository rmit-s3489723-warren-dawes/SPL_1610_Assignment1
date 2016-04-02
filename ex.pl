#!/usr/bin/env perl
use strict;
use warnings;

open my $openfile, "emails.json" or die "Error opening file: $!\n";

my %kv_blocks;

my $line_num = 0;

my @emails; # An array of emails
my $emailCount = -1; #A count to track the position in the email array

# open file and read each line
while (<$openfile>)
{	
	# debug: line number
	$line_num++;
	
	# remove leading/trailing white-spaces
	$_ =~ s/^\s+|\s+$//g;
	
	# if a new block we prepare for key/value pairs
	if ($_ =~ m/{/)
	{
		$emailCount++;
		next;
	}
	
	my $existingHash = $emails[$emailCount];
	my $newHash = contentExtractor();
	
	if($existingHash && $newHash)
	{
		my$mergedHash = {%$existingHash, %$newHash};
		$emails[$emailCount] = $mergedHash;
	}
	elsif($newHash)
	{
		$emails[$emailCount] = $newHash;
	}
}

#print data
print "Number of emails: ";
print (scalar @emails);
print "\n-------------------\n";
for (my $i = 0; $i < (scalar @emails); $i++) 
{
	my $hash = $emails[$i];
	if ($hash) 
	{
		my @keys = keys $hash;
	
		for (my $j = 0; $j < (scalar @keys); $j++) 
		{
			print $keys[$j];
			print " : ";
			print $hash->{$keys[$j]};
			print "\n";
		}
	
		print "-------------------\n";
	}
	
}
#end print data

close $openfile;

#Subroutine that returns a hash from one 
sub contentExtractor {
	
	# if within the key/value portion - we preserve contents
	if ($_ =~ /^"/)
	{
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
		my $existingHash->{$extract_key} = $extract_value;
		return $existingHash;
	}
}



# # debug: perform web-request with timezone
		# if ($extract_key eq "timeZone")
		# {
			# my $contents = get("http://api.timezonedb.com/?key=EHUCC69JBOJT&zone=$extract_value");
			# print $contents;
		# }