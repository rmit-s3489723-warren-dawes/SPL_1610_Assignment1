#!/usr/bin/env perl
use strict;
use warnings;

=pod

=head1 B<NAME>

Assignment 1 - Event Extractor

=head2 B<AUTHORS>

=over 4

=item *

Warren Dawes

=item *

Candy Goodison

=back

=head2 B<DESCIPTION>

An email event-extractor to gather dates for events based on contents of emails.

=head2 C<Copyright Warren Dawes & Candy Goodison @ 2016>

=cut

open my $openfile, "emails.json" or die "Error opening file: $!\n";

my $line_num = 0;

my @emails; # An array of email hashes
my $emailCount = -1; #A count to track the position in the email array

# open file and read each line
while (<$openfile>)
{	
	# debug: line number
	$line_num++;
	
	# remove leading/trailing white-spaces of current line
	$_ =~ s/^\s+|\s+$//g;
	
	# get the key/value from current line
	my ($key, $value) = contentExtractor();
	
	# if the key/value were found (within double-quotes and seperated by a colon)
	if ($key && $value) {
		keyValueParse($key, $value);
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
			print "$i->$keys[$j]";
			print " : ";
			print $hash->{$keys[$j]};
			print "\n";
		}
	
		print "-------------------\n";
	}
	
}
#end print data

close $openfile;

=pod

=head2 KeyValueParse($key, $value)

$key is a string of the key from the line, $value is a string of the value from the line.

=cut

#parse key/value for case
sub keyValueParse {
	my $key = shift;
	my $value = shift;
	
	# if type doesnt equal email (should never occur)
	# we exit, and if it does, we return (to not store key/value)
	if ($key eq "type") {
		if ($value ne "email") {
			exit;
		}
		return;
	}
	
	# we return on items to block storing of key/value
	if ($key eq "items") {
		return;
	}
	
	# if sent key, increment email count
	# and set default timeType
	if ($key eq "sent") {
		$emailCount++;
		$emails[$emailCount]->{'timeType'} = "date";
	}
	
	# if timeZone key specified, we change email type
	# to datetime as the event has time-specific
	if ($key eq "timeZone") {
		$emails[$emailCount]->{'timeType'} = "datetime";
	}
	
	$emails[$emailCount]->{$key} = $value;
}

=pod

=head2 ContentExtractor() return ($key, $value)

$key is a string of the key from the line, $value is a string of the value from the line.

=cut

#sub to extract key/value pair
sub contentExtractor {
	
	# new variables
	my $extract_key;
	my $extract_value;
	
	# if within the key/value portion - we preserve contents
	if ($_ =~ /^"/)
	{		
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
		
	}
	
	return $extract_key, $extract_value;
}
#end extract


# # debug: perform web-request with timezone
		# if ($extract_key eq "timeZone")
		# {
			# my $contents = get("http://api.timezonedb.com/?key=EHUCC69JBOJT&zone=$extract_value");
			# print $contents;
		# }