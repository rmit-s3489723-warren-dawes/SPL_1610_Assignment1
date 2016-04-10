#!/usr/bin/env perl
use strict;
use warnings;
use EventExtractor;

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

my $inputFile;
my $outputFile;

# upperbound not set aka -1
if ($#ARGV == -1)
{
	$inputFile = "emails.json";
	$outputFile = "events.json";
}

# upperbound set to 0 aka inputFile specified
if ($#ARGV == 0)
{
	$inputFile = $ARGV[0];
}

# upperbound set to 1 aka inputFile and outputFile specified
if ($#ARGV == 1)
{	
	$inputFile = $ARGV[0];
	$outputFile = $ARGV[1];
}

# attempt to open via inputFile or die
open my $openfile, $inputFile or die "Error opening file: $!\n";

my $line_num = 0;

my @emails; # An array of email hashes
my $emailKey = -1; #A count to track the position in the email array

# open file and read each line
while (<$openfile>)
{	
	# debug: line number
	$line_num++;
	
	# get the key/value from current line
	my ($key, $value) = EventExtractor::KeyValueExtractor();
	
	# if the key/value were found (within double-quotes and seperated by a colon)
	if ($key && $value)
	{
		# generate struct with key/value
		# passing by reference
		EventExtractor::EmailStructBuilder(\@emails, \$emailKey, $key, $value);
	}	
}

close $openfile;

EventExtractor::EmailPrinter(\@emails);

my @events;

EventExtractor::EmailContentParser(\@emails, \@events);

# now we parse the content field of each email