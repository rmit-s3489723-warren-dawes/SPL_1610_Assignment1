#!/usr/bin/env perl
use strict;
use warnings;
use EventExtractor qw(DebugPrint KeyValueExtractor EmailStructBuilder EmailPrinter EmailContentParser);

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

my ($inputFile, $outputFile)=commandArgsHandler(\@ARGV);

my $openFile = fileOpener($inputFile);

my $line_num = 0;

my @emails; # An array of email hashes
my $emailKey = -1; #A count to track the position in the email array

# open file and read each line
while (<$openFile>)
{	
	# debug: line number
	$line_num++;
	
	# get the key/value from current line
	my ($key, $value) = KeyValueExtractor($_, '"(.*?)"\s?:\s?"(.*?)"', '"(.*?)"');
	
	# if the key/value were found (within double-quotes and seperated by a colon)
	if ($key && $value)
	{
		DebugPrint("->$key|$value<-\n");
		
		# generate struct with key/value
		# passing by reference
		EmailStructBuilder(\@emails, \$emailKey, $key, $value);
	}	
}

close $openFile;

EmailPrinter(\@emails);

my @events;
my $eventKey = 0;

EmailContentParser(\@emails, \@events, \$eventKey);

sub commandArgsHandler{
		
	# upperbound not set aka -1
	if ($#ARGV == -1)
	{
		$inputFile = "emails.json";
		$outputFile = "events.json";
		print "You didn't specify any input or output files. We will try to use default input file \"emails.json\"and print to default output file \"events.json\".\n";
	}

	# upperbound set to 0 aka inputFile specified
	if ($#ARGV == 0)
	{
		$inputFile = $ARGV[0];
		
		if ($inputFile !~/json/)
		{
			print "Invalid file, please choose a .json type file to read from.\n";
			exit;
		}
		print "We will use \"$inputFile\" to read events from, and print to default output file \"events.json\".\n";
	}

	# upperbound set to 1 aka inputFile and outputFile specified
	if ($#ARGV == 1)
	{	
		$inputFile = $ARGV[0];
		$outputFile = $ARGV[1];
		print "We will read from \"$inputFile\" and output events to \"outputFile\".\n";
	}

	return($inputFile, $outputFile);
}

sub fileOpener{
	# attempt to open via inputFile or die
	open my $openFile, $inputFile or do{
	print "Error opening file \"$inputFile\": $!. Please enter a valid file.\n";
	exit;
	};

	return $openFile;
}