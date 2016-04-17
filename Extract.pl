#!/usr/bin/env perl
use strict;
use warnings;
use EventExtractor qw(ReportPrint DebugPrint KeyValueExtractor EmailStructBuilder EmailPrinter EmailContentParser PrintOutput);

=pod

=head2 NAME

Extract.pl - Sample script showing implementation of the EventExtractor module.

=head2 SYNOPSIS

This script supports 3 types of usage:
perl Extract.pl
perl Extract.pl input.json
perl Extract.pl inout.json output.json

I<Note:Input and output can be any file extension, but just represet JSON format.>

=head2 BUGS 

Please report any bugs detected to s3489723@student.rmit.edu.au or s3285133@student.rmit.edu.au.

Please provide details on the input/output formats desired so that support can be implemented.

=head2 ACKNOWLEDGEMENTS

We would like to thank RMIT University for offering Scripting Language Programming as a course, the tutors/staff involved with this course and B<Dr Andy Song> for being so cool.

=head2 COPYRIGHT & LICENCE

The contents of this module/script are free to be used where applicable, with sufficient crediting where appropriate.

Copyright Warren Dawes & Candy Goodison @ 2016

PLEASE DO NOT REDISTRIBUTE!!

=head2 AVAILABILITY

Support for the module/script ends after Semester 1 - 2016.

=head2 AUTHORS

This module/script was constructed over several weeks by the following individuals:

=over 4

=item *

Warren Dawes - s3489723@student.rmit.edu.au

=item *

Candice Goodison - s3285133@student.rmit.edu.au

=back

=head2 SEE ALSO

L<http://www1.rmit.edu.au/courses/014048>, L<https://juerd.nl/site.plp/perlpodtut>

-----------------------------------------------------------------------------------------------------------

=head2 METHODS

These are the subs which are used within this script:

=over 8

=item C<CommandArgsHandler()>

Checks if any arguments were supplied to the script and attempts to set an input/output file.
If found, these overwrite default (emails.json and events.json).

=item C<FileOpener($inputFile)>

Attempts to open the file containing all emails to process.
I<Note:This method will die if unable to open the emails file.>

=item C<PrintToConsole($string)>

Print $string to console (where $string is important).

=back

=cut

#parse command args
#assign if supplied
my ($inputFile, $outputFile)=CommandArgsHandler(\@ARGV);

#open file to read
my $openFile = FileOpener($inputFile);

my @emails; # An array of email hashes
my $emailKey = -1; #A count to track the position in the email array

# open file and read each line
while (<$openFile>)
{		
	# get the key/value from current line
	my ($key, $value) = KeyValueExtractor($_);
	
	# if the key/value were found (within double-quotes and seperated by a colon)
	if ($key && $value)
	{
		# generate struct with key/value
		# passing by reference
		EmailStructBuilder(\@emails, \$emailKey, $key, $value);
	}	
}

#close file
close $openFile;

#output emails that were processed
EmailPrinter(\@emails);

#create events array to store any events
my @events;
my $eventKey = 0;	#default eventKey for index 0

#process each emails content field etc
EmailContentParser(\@emails, \@events, \$eventKey);

#output to file with extracted events
PrintOutput(\@events, $outputFile);

sub CommandArgsHandler {
		
	# upperbound not set aka -1
	if ($#ARGV == -1)
	{
		$inputFile = "emails.json";
		$outputFile = "events.json";
		PrintToConsole("You didn't specify any input or output files. We will try to use default input file \"emails.json\"and print to default output file \"events.json\".\n");
	}

	# upperbound set to 0 aka inputFile specified
	if ($#ARGV == 0)
	{
		$inputFile = $ARGV[0];
		
		if ($inputFile !~/.json$/ && $inputFile !~/.txt$/)
		{
			PrintToConsole("Invalid file, please choose a .json or .txt extension file to read from.\n");
			exit;
		}
		PrintToConsole("We will use \"$inputFile\" to read events from, and print to default output file \"events.json\".\n");
		PrintToConsole("-------------------\n");
	}

	# upperbound set to 1 aka inputFile and outputFile specified
	if ($#ARGV == 1)
	{	
		$inputFile = $ARGV[0];
		$outputFile = $ARGV[1];
		PrintToConsole("We will read from \"$inputFile\" and output events to \"outputFile\".\n");
		PrintToConsole("-------------------\n");
	}

	return($inputFile, $outputFile);
}

sub FileOpener {
	# attempt to open via inputFile or die
	open my $openFile, $inputFile or do{
		#strip newline
		chomp $!;
		die("Error opening file \"$inputFile\": $!. Please enter a valid file.\n");
	};

	return $openFile;
}

sub PrintToConsole {
	print shift;
}