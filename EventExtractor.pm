#!/usr/bin/env perl
package EventExtractor;
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(ReportPrint DebugPrint KeyValueExtractor EmailStructBuilder EmailPrinter EmailContentParser PrintOutput);

use strict;
use warnings;

use LWP::Simple;

use POSIX;
use Time::Seconds;
use Time::Piece ':override';

use Date::Parse;
use Date::Format 'time2str';

#can be changed to suit year (that is parsed by default)
my $YEAR = 2016;

=head2 NAME

EventExtractor.pm - Process emails and extract events based on dates/timestamps in various formats.

=head2 SYNOPSIS

See the SYNOPSIS section of Extract.pl.

=head2 BUGS 

Although various formats are supported, please report any unknown or corrupted formats to s3489723@student.rmit.edu.au or s3285133@student.rmit.edu.au.	

Please provide details on the format (including the expected trigger - such as "every Wednesday 2pm - 5pm" or "25-02-2016 - 29-02-2016").

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

=head2 EXPORTED METHODS

These are the subs which are exported with module usage:

=over 8

=item C<KeyValueExtractor($string)>

Attempts to seek $string for key/value in JSON format ("key":"value" or "key":value).
I<Note:value B<MUST> be in number format when not surrounded by double-quotes.>

=item C<EmailStructBuilder(\@emails, \$emailKey, $key, $value)>

Appends the latest $key and $value to the \@emails array, incrementing \$emailKey accordingly.
I<Note:@emails and $emailKey B<MUST> be passed by reference.>

=item C<EmailPrinter(\@emails)>

Iterates through each email and prints detailed information on each.

=item C<EmailContentParser(\@emails, \@events, \$eventKey)>

Iterates through each email to seek for any events (which are stored in \@events array), incrementing \$eventKey accordingly.
I<Note:@emails, @events and $eventKey B<MUST> be passed by reference.>

=item C<PrintOutput(\@events, $outputFile)>

Iterates through each event and print to a file with appropriate formating (JSON).
I<Note:@events B<MUST> be passed by reference.>

=item C<DebugPrint($string)>

Print $string to console (used to mass-enable or mass-disable).

=item C<ReportPrint($string)>

Print $string to console (where $string is important).

=back

-----------------------------------------------------------------------------------------------------------

=head2 INTERNAL METHODS

These are the subs which are used within the module:

=over 8

=item C<EventDateProcess($events, $eventKey, \$sentField, \$contentField, \$timeTypeField, \$timeZoneField, $relativeTerm)>

Called by EmailContentParser to seek and extract any dates that are within the current \$contentField, when found, the sub will automatically parse and add to the $events array with the $eventKey, incrementing accordingly.
The $relativeTerm is unused within this sub (but possible implementation could support "this year" or "next year").
This supports seeking with time-ranges as well (such as 18th of April, 2016 4pm - 10pm) in various formats.
I<Note:$events is already a reference to the array, as with $eventKey, but \$sentField, \$contentField, \$timeTypeField and \$timeZoneField B<MUST> be passed by reference.>

=item C<EventTimeProcess($events, $eventKey, \$sentField, \$contentField, \$timeTypeField, \$timeZoneField, $relativeTerm)>

Called by EmailContentParser to seek and extract any times that are within the current \$contentField, when found, the sub will automatically parse and add to the $events array with the $eventKey, incrementing accordingly.
The $relativeTerm is used to seek matches that follow key-words (such as today 4pm or tomorrow 4pm), all seeking is done with case insensitivity.
This supports seeking with time-ranges as well (such as 4pm - 8pm) in various formats.
I<Note:$events is already a reference to the array, as with $eventKey, but \$sentField, \$contentField, \$timeTypeField and \$timeZoneField B<MUST> be passed by reference.>

=item C<EventDayTimeProcess($events, $eventKey, \$sentField, \$contentField, \$timeTypeField, \$timeZoneField, $relativeTerm)>

Called by EmailContentParser to seek and extract any daytimes that are within the current \$contentField, when found, the sub will automatically parse and add to the $events array with the $eventKey, incrementing accordingly.
The $relativeTerm is used to seek matches that follow key-words (such as this Monday, or next Monday), all seeking is done with case insensitivity.
This supports seeking with time-ranges as well (such as Monday 4pm - 8pm) in various formats.
I<Note:$events is already a reference to the array, as with $eventKey, but \$sentField, \$contentField, \$timeTypeField and \$timeZoneField B<MUST> be passed by reference.>

=item C<EventTimeParse($eventTrigger, \$eventStart, \$eventDuration, $datediff)>

Called by EventDateProcess, EventTimeProcess or EventDayTimeProcess to process a time (or time-range), setting the \$eventStart and \$eventDuration accordingly.
This sub also uses $datediff to sync the default UTC time to the timezone required.
$eventTrigger should be the time (such as "4pm" or "4pm - 8pm") - supporting various formats (such as 16:00 - 20:00).
I<Note:$eventTrigger needs to be as clean as possible, such that there is no other characters but those specified in normal time formats.>

=item C<EventAppend($events, $eventKey, $section, $key, $value)>

Called by EventDateProcess, EventTimeProcess and EventDayTimeProcess to append to the events array.
This essentially stacks a new event ontop of the others.
I<Note:$events is already a reference to the array, but the other variables can be passed by value.>

=back

-----------------------------------------------------------------------------------------------------------

=head2 KEY VARIABLES

These are the subs which are used within the module:

=over 8

=item C<%dayofweek>

A hash table containing string representations of the days to seek matched against the appropriate day-of-the-week.
Alternatives can be added here (such as other abbreviations).

=item C<%monthofyear>

A hash table containing string representations of the months of the year to seek matched against the appropriate month number (1-index based).
Alternatives can be added here (such as other abbreviations).

=item C<%relativeSeek>

A hash table containing string representations of the key-words to seek matched against the type of key-word (such that the processor knows what to seek).
Alternatives can be added here (such as "fortnight" => "daytime" - which would seek 2 weeks ahead of time, for any day + time events (or just day)).

=item C<@daytimePattern>

An array containing broken down patterns to seek for any daytime events.
These are appended together with the alternation character ('|') to create a single regular expression.
An example of a daytime is "Monday" or "Monday 4pm", where by a time and/or time-range can be provided.
I<Note:For any additions, please revise previous expressions and capture unique groups.>

=item C<@timePattern>

An array containing broken down patterns to seek for any time events.
These are appended together with the alternation character ('|') to create a single regular expression.
An example of a time is "4pm" or "4pm - 8pm", where by a time and/or time-range can be provided.
I<Note:For any additions, please revise previous expressions and capture unique groups.>

=item C<@datePattern>

An array containing broken down patterns to seek for any date events.
These are appended together with the alternation character ('|') to create a single regular expression.
An example of a time is "2015 01 12" or "18th April, 2016" or "18th April, 2016 4pm", where by a time and/or time-range can be appended to these dates.
I<Note:For any additions, please revise previous expressions and capture unique groups.>

=item C<%datediff>

A hash table containing string representations of the timezones detected from emails matched against the appropriate datediff (seconds in difference from the UTC vs timezone).
An example entry is "Australia/Melbourne" => 36000 - which would represent 36000 seconds ahead of UTC.
I<Note:These are gathered from a web-request after processing all emails.>

=back

=cut

#reference for day of the week
#http://www.aresearchguide.com/monthdayabb.html
my %dayofweek =
(
	"monday" => 1,
	"tuesday" => 2,
	"wednesday" => 3,
	"thursday" => 4,
	"friday" => 5,
	"saturday" => 6,
	"sunday" => 7,
	
	"mon." => 1,
	"tu." => 2,
	"tue." => 2,
	"tues." => 2,
	"wed." => 3,
	"th." => 4,
	"thu." => 4,
	"thur." => 4,
	"thurs." => 4,
	"fri." => 5,
	"sat." => 6,
	"sun." => 7,
);

#reference for month of the year
#http://www.aresearchguide.com/monthdayabb.html
my %monthofyear =
(
	"january" => 1,
	"february" => 2,
	"march" => 3,
	"april" => 4,
	"may" => 5,
	"june" => 6,
	"july" => 7,
	"august" => 8,
	"september" => 9,
	"october" => 10,
	"november" => 11,
	"december" => 12,
	
	"jan." => 1,
	"feb." => 2,
	"mar." => 3,
	"apr." => 4,
	"may." => 5,
	"jun." => 6,
	"jul." => 7,
	"aug." => 8,
	"sept." => 9,
	"oct." => 10,
	"nov." => 11,
	"dec." => 12,
);

#relative terms to seek
#eg this Monday, next Thursday 4pm
my %relativeSeek =
(
	"this" => "daytime",		#eg Monday or Monday 4pm or Monday 16:00
	"next" => "daytime",		#eg next Monday or next Monday 4pm or next Monday 16:00

	"today" => "time",		#eg today 4pm or today 4am or today 16:00
	"tomorrow" => "time",		#eg tomorrow 4pm or tomorrow 4am or tomorrow 16:00
);

#patterns are joined together with an | operator (or clause)
#eg join('|', @daytimePattern)
my @daytimePattern = 
(
	#pattern for day/time with range = eg Monday 4:30pm - 5:30pm or Monday 4pm - 5:30pm or Monday 4:30pm - 5pm or Monday 4pm - 5pm or Monday 16:00 - 17:00
	#pattern for day/time = eg Monday 4pm or Monday 4:30pm or Monday 16:00
	#pattern for day = Monday (would set as an all-day event)
	'\b$[-\s~,\.]{1,2}(?:\d{1,2}:\d{2}|\d{1,2})(?:\s[pa]m|[pa]m)(?:[-\s~]{1,3}(?:\d{1,2}:\d{2}|\d{1,2})(?:\s[pa]m|[pa]m))?',	#match monday( )1pm - 3pm and monday( )1pm - 3:30pm
	'\b$[-\s~,\.]{1,2}\d{1,2}:\d{2}(?:[-\s~]{1,3}\d{1,2}:\d{2})?',									#match monday( )13:30 - 15:30
	'\b$[-\s~,\.]{1,2}(?:\d{1,2}:\d{2}|\d{1,2})(?:[-\s~]{1,3}(?:\d{1,2}:\d{2}|\d{1,2})(?:\s[pa]m|[pa]m))?',				#match monday( )1 - 3pm and monday( )1 - 3:30pm
);

#patterns are joined together with an | operator (or clause)
#eg join('|', @timePattern)
my @timePattern = 
(
	#pattern for time with range = eg today 4pm or today at 4pm or today 4pm - 6pm or today between 4pm - 6pm (allows for precise time - 4:00pm etc)
	#pattern for today and tomorrow (would set as an all-day event)
	'\b$\b(?: at | between |\s)(?:\d{1,2}|\d{1,2}:\d{2})(?:\s[pa]m|[pa]m)(?:[-\s~]{1,3}(?:\d{1,2}|\d{1,2}:\d{2})(?:\s[pa]m|[pa]m))?',	#match today( at | between | )1pm - 3pm
	'\b$\b(?: at | between |\s)\d{1,2}:\d{2}(?:[-\s~]{1,3}\d{1,2}:\d{2})?',									#match today( at | between | )13:30 - 15:30
	'\b$\b(?: at | between |\s)(?:\d{1,2}|\d{1,2}:\d{2})(?:[-\s~]{1,3}(?:\d{1,2}|\d{1,2}:\d{2})(?:\s[pa]m|[pa]m))?',			#match today( at | between | )1 - 3pm and monday( )1 - 3:30pm
);

#patterns are joined together with an | operator (or clause)
#eg join('|', @datePattern)
my @datePattern =
(
	'\b$[-\s~,.]{1,3}\d{1,2}(?:st|th|nd|rd)?[-\s~,.]{1,3}(?:\d{4}|\d{2})(?:[-\s~,.]{1,3}(?:\d{1,2}:\d{2}|\d{1,2})(?:\s[pa]m|[pa]m)(?:[-\s~]{1,3}(?:\d{1,2}:\d{2}|\d{1,2})(?:\s[pa]m|[pa]m))?)', 	#match April-(4|14)(th)-(2006|06) with time/duration
	'\d{1,2}(?:st|th|nd|rd)?[-\s~,.]{1,3}$[-\s~,.]{1,3}(?:\d{4}|\d{2})(?:[-\s~,.]{1,3}(?:\d{1,2}:\d{2}|\d{1,2})(?:\s[pa]m|[pa]m)(?:[-\s~]{1,3}(?:\d{1,2}:\d{2}|\d{1,2})(?:\s[pa]m|[pa]m))?)',	#match (4|14)(th)-April-(2006|06) with time/duration
	
	'\b$[-\s~,.]{1,3}\d{1,2}(?:st|th|nd|rd)?[-\s~,.]{1,3}(?:\d{4}|\d{2})(?:[-\s~,.]{1,3}(?:\d{1,2}:\d{2}|\d{1,2})(?:[-\s~]{1,3}(?:\d{1,2}:\d{2}|\d{1,2})(?:\s[pa]m|[pa]m))?)', 			#match April-(4|14)(th)-(2006|06) with time/duration (allowing 12 - 2pm format)
	'\d{1,2}(?:st|th|nd|rd)?[-\s~,.]{1,3}$[-\s~,.]{1,3}(?:\d{4}|\d{2})(?:[-\s~,.]{1,3}(?:\d{1,2}:\d{2}|\d{1,2})(?:[-\s~]{1,3}(?:\d{1,2}:\d{2}|\d{1,2})(?:\s[pa]m|[pa]m))?)',			#match (4|14)(th)-April-(2006|06) with time/duration (allowing 12 - 2pm format)
	
	'\b$[-\s~,.]{1,3}\d{1,2}(?:st|th|nd|rd)?(?:[-\s~,.]{1,3}(?:\d{1,2}:\d{2}|\d{1,2})(?:\s[pa]m|[pa]m)(?:[-\s~]{1,3}(?:\d{1,2}:\d{2}|\d{1,2})(?:\s[pa]m|[pa]m))?)',					#match April-(4|14)(th) (assumes that its this year) with time/duration
	'\d{1,2}(?:st|th|nd|rd)?[-\s~,.]{1,3}$(?:[-\s~,.]{1,3}(?:\d{1,2}:\d{2}|\d{1,2})(?:\s[pa]m|[pa]m)(?:[-\s~]{1,3}(?:\d{1,2}:\d{2}|\d{1,2})(?:\s[pa]m|[pa]m))?)',					#match (4|14)(th)-April (assumes that its this year) with time/duration

	'\b$[-\s~,.]{1,3}\d{1,2}(?:st|th|nd|rd)?[-\s~,.]{1,3}(?:\d{4}|\d{2})',		#match April-(4|14)(th)-(2006|06)
	'\d{1,2}(?:st|th|nd|rd)?[-\s~,.]{1,3}$[-\s~,.]{1,3}(?:\d{4}|\d{2})',		#match (4|14)(th)-April-(2006|06)

	'\b$[-\s~,.]{1,3}\d{1,2}(?:st|th|nd|rd)?(?:[-\s~,.]{1,3}(?:\d{1,2}:\d{2}|\d{1,2})(?:[-\s~]{1,3}(?:\d{1,2}:\d{2}|\d{1,2})(?:\s[pa]m|[pa]m))?)',							#match April-(4|14)(th) (assumes that its this year) with time/duration (allowing 12 - 2pm format)
	'\d{1,2}(?:st|th|nd|rd)?[-\s~,.]{1,3}$(?:[-\s~,.]{1,3}(?:\d{1,2}:\d{2}|\d{1,2})(?:[-\s~]{1,3}(?:\d{1,2}:\d{2}|\d{1,2})(?:\s[pa]m|[pa]m))?)',							#match (4|14)(th)-April (assumes that its this year) with time/duration (allowing 12 - 2pm format)
	
	'\b$[-\s~,.]{1,3}\d{1,2}(?:st|th|nd|rd)?[^-\s~,.]\b',				#match April-(4|14)(th) (assumes that its this year)
	'\d{1,2}(?:st|th|nd|rd)?[-\s~,.]{1,3}$\b[^-\s~,.]\b',				#match (4|14)(th)-April (assumes that its this year)
	
	'\d{4}[-\s~,.]{1,3}#[-\s~,.]{1,3}\d{1,2}',					#match 2015 01 20 (spaces can be [-\s~,.])
	'\d{4}[-\s~,.]{1,3}\d{1,2}[-\s~,.]{1,3}#',					#match 2015 20 01 (spaces can be [-\s~,.])
);

#hash table for datediff for futuer use (to minus from time to match local)
my %datediff = ('Australia/Melbourne' => 36000);	#match +10 GMT aka +10 hours to UTC

sub EmailContentParser {
	my $emails = shift;
	my $events = shift;
	my $eventKey = shift;
	my $emailKey = 0;
	
	#construct global datediff hash
	for ($emailKey = 0; $emailKey < (scalar @$emails); $emailKey++)
	{
		my $email = $$emails[$emailKey];
		my $timeTypeField = $email->{'timeType'};
		my $timeZoneField = $email->{'timeZone'};
		
		if ($timeTypeField eq 'datetime')
		{
			$datediff{$timeZoneField} = 0;
		}
	}	
	
	#fetch datediff for future use
	foreach my $timezone (keys %datediff)
	{
		#use api to fetch datediff	
		my $contents = get("http://api.timezonedb.com/?key=EHUCC69JBOJT&zone=$timezone&format=json");
		
		DebugPrint("->$contents<-\n");
		
		my %json = KeyValueExtractor($contents);
		
		my $gmtOffset = $json{'gmtOffset'};
		
		DebugPrint("->$timezone|$gmtOffset<-\n");
		
		$datediff{$timezone} = $gmtOffset;
	}
	
	
	#parse content field to seek
	for ($emailKey = 0; $emailKey < (scalar @$emails); $emailKey++)
	{
		my $email = $$emails[$emailKey];
		if ($email) 
		{
			#store fields from emails
			my $sentField = $email->{'sent'};
			my $contentField = $email->{'content'};
			my $timeTypeField = $email->{'timeType'};
			my $timeZoneField = $email->{'timeZone'};
			
			if ($emailKey >= 0) #&& $emailKey <= 3)
			{							
				ReportPrint("-------------------\n");
				
				ReportPrint("$emailKey->content : $contentField\n");
				
				ReportPrint("-------------------\n");
					
				#iterate for relative seek
				foreach my $relativeTerm (keys %relativeSeek)
				{
					#foreach identified seek
					foreach my $rsMatch ($contentField =~ m/$relativeTerm+/ig)
					{						
						#if the seek type is daytime
						#eg next/this
						if ($relativeSeek{$relativeTerm} eq "daytime")
						{
							EventDayTimeProcess($events, $eventKey, \$sentField, \$contentField, \$timeTypeField, \$timeZoneField, $relativeTerm);
						}
						
						#if seek type is time
						#eg today/tomorrow
						if ($relativeSeek{$relativeTerm} eq "time")
						{
							EventTimeProcess($events, $eventKey, \$sentField, \$contentField, \$timeTypeField, \$timeZoneField, $relativeTerm);
						}
					}
				}
				
				ReportPrint("->SEEK REMAINING<-\n");
				
				#iterate for date searching
				EventDateProcess($events, $eventKey, \$sentField, \$contentField, \$timeTypeField, \$timeZoneField, "");
				
				#seek remaining to match any daytime events
				EventDayTimeProcess($events, $eventKey, \$sentField, \$contentField, \$timeTypeField, \$timeZoneField, "");
				
				#seek remaining to match any time events
				EventTimeProcess($events, $eventKey, \$sentField, \$contentField, \$timeTypeField, \$timeZoneField, "");
			}
		}
	}
	
	EventPrinter($events);
}

sub EventDateProcess{
	
	my $events = shift;
	my $eventKey = shift;
	my $sentField = shift;
	my $contentField = shift;
	my $timeTypeField = shift;
	my $timeZoneField = shift;
	my $relativeTerm = shift;
	
	DebugPrint("->EventDateProcess{()<-\n");
	
	ReportPrint("-------------------\n");
	ReportPrint("->EVENTDATEPROCESS()<-\n");
	
	#strip spaces/specific characters
	$$sentField =~ s/\s+|T+|-+|:+|.00Z+//g;  #thids makes sent field into a numbers only format ie 20160312 (24hr)
	
	#convert to a friendly format (inclusive of day)
	my $sentDate = Time::Piece->strptime($$sentField, "%Y%m%d%H%M%S");
	
	my $eventType = "date";		#default as a date (datetime if time specified)
	my $eventDuration = ONE_DAY;	#24 hours of seconds
	my $eventStart = $sentDate;

	#attempt to discover the month (either short-hand or full-word)
	foreach my $month (keys %monthofyear)
	{
		#store copy and replace pattern
		my $usePattern = join('|', @datePattern);
		#replace $ symbol in regex with month
		$usePattern =~ s/\$/$month/g;
		
		#get number to represent month
		my $monthNumber = sprintf("%02d", $monthofyear{$month});
		my $monthName = $month;
		
		#replace # symbol in regex with month number
		$usePattern =~ s/\#/$monthNumber/g;
		
		#each result found with pattern (which has $ replaced with month)			
		my @dateSeek = $$contentField =~ m/$usePattern/ig;
		
		foreach my $eventTrigger (@dateSeek)
		{
			if (not $eventTrigger) { next; }
			
			DebugPrint("->FOUND:$eventTrigger<-\n");										
			
			ReportPrint("->EXTRACTED:$eventTrigger<-\n");
			
			#DebugPrint("->$$contentField<-\n");
			
			$$contentField =~ s/$eventTrigger//;	
			
			#strip leading and trailing whitespaces
			$eventTrigger =~ s/^\s*|\s*$//g;
			
			#attempt to get a time (to be used on that date)
			my $dateTime = join("", $eventTrigger =~ m/ (?:\d{1,2}:\d{2}|\d{1,2})(?:[-\s~]{1,3}(?:\d{1,2}|\d{1,2}:\d{2})(?:\s[pa]m|[pa]m))| (?:\d{1,2}:\d{2}|\d{1,2})(?:\s[pa]m|[pa]m)(?:[-\s~]{1,3}(?:\d{1,2}|\d{1,2}:\d{2})(?:\s[pa]m|[pa]m))?/ig);

			#if a datetime was found
			if ($dateTime)
			{
				#set event as datetime
				$eventType = "datetime";
				
				#strip it from trigger
				$eventTrigger =~ s/$dateTime//g;
				
				#strip leading and trailing whitespaces
				$dateTime =~ s/^\s*|\s*$//g;
				
				DebugPrint("->DATETIME:$dateTime<-\n");
				
				#replace any invalid characters
				$eventTrigger =~ s/(st[\s,]+|th[\s,]+|nd[\s,]+|rd[\s,]+)|[-\s,\.]+/-/ig;
					
				DebugPrint("->STRIPPED:$eventTrigger<-\n");

				my $parsePattern;
				
				if ($eventTrigger =~ m/\b\d{2,4}-$monthNumber-\d{1,2}\b/i)	#this would match 06-04-02 or 2006-04-02
				{
					DebugPrint("->year-month(number)-day<-\n");
					
					#if year is 2 digit format
					if ($eventTrigger =~ m/\b\d{2}-$monthNumber-\d{1,2}\b/i)
					{
						$parsePattern = '%y-%m-%d';
						
					}
					elsif ($eventTrigger =~ m/\b\d{4}-$monthNumber-\d{1,2}\b/i)
					{
						$parsePattern = '%Y-%m-%d';
					}
				}
				elsif ($eventTrigger =~ m/\b\w+-\d{1,2}-\d{2,4}\b/i)	#this would match April-02-06 or April-02-2006
				{
					DebugPrint("->month(text)-day-year<-\n");
					
					#if year is 2 digit format
					if ($eventTrigger =~ m/\b\w+-\d{1,2}-\d{2}\b/i)
					{
						#if abbreviated (eg Apr.)
						if ($monthName =~ m/\.$/i)
						{							
							$parsePattern = '%b-%d-%y';
						}
						else
						{
							$parsePattern = '%B-%d-%y';
						}
						
					}
					elsif ($eventTrigger =~ m/\b\w+-\d{1,2}-\d{4}\b/i)
					{
						#if abbreviated (eg Apr.)
						if ($monthName =~ m/\.$/i)
						{							
							$parsePattern = '%b-%d-%Y';
						}
						else
						{
							$parsePattern = '%B-%d-%Y';
						}
					}
				}
				elsif ($eventTrigger =~ m/\b\d{1,2}-\w+-\d{2,4}\b/i)		#this would match 02-April-06 or 02-April-2006
				{
					DebugPrint("->day-month(text)-year<-\n");
					
					#if year is 2 digit format
					if ($eventTrigger =~ m/\b\d{1,2}-\w+-\d{2}\b/i)
					{
						DebugPrint("->2digityear<-\n");
						
						#if abbreviated (eg Apr.)
						if ($monthName =~ m/\.$/i)
						{							
							$parsePattern = '%d-%b-%y';
						}
						else
						{
							$parsePattern = '%d-%B-%y';
						}
						
					}
					elsif ($eventTrigger =~ m/\b\d{1,2}-\w+-\d{4}\b/i)
					{
						DebugPrint("->4digityear<-\n");
						
						#if abbreviated (eg Apr.)
						if ($monthName =~ m/\.$/i)
						{							
							$parsePattern = '%d-%b-%Y';
						}
						else
						{
							$parsePattern = '%d-%B-%Y';
						}
					}
				}
				elsif ($eventTrigger =~ m/\b\d{1,2}-\w+|\w+\d{1,2}\b/i)	#this would match April-02 or 02-April
				{
					DebugPrint("->day-month(text)|month(text)-day<-\n");
					
					#if day-month
					if ($eventTrigger =~ m/\b\d{1,2}-\w+\b/i)
					{
						#if abbreviated (eg Apr.)
						if ($monthName =~ m/\.$/i)
						{							
							$parsePattern = '%d-%b-%Y';
						}
						else
						{
							$parsePattern = '%d-%B-%Y';
						}						
					}
					elsif ($eventTrigger =~ m/\b\w+\d{1,2}\b/i)
					{
						#if abbreviated (eg Apr.)
						if ($monthName =~ m/\.$/i)
						{							
							$parsePattern = '%b-%d-%Y';
						}
						else
						{
							$parsePattern = '%B-%d-%Y';
						}
					}
					
					#append current year
					$eventTrigger .= "-$YEAR";
				}
				
				DebugPrint("->$parsePattern<-\n");
				
				#convert to a friendly format based on input
				#allow errors
				my $parsedDate;
				eval { $parsedDate = Time::Piece->strptime($eventTrigger, $parsePattern); };
				if($@) {
					#strip newline
					chomp $@;
					
					# print error
					ReportPrint("-------------------\n");
					ReportPrint("->ERROR:$@<-\n");
					ReportPrint("->PATTERN:$parsePattern<-\n");
					ReportPrint("-------------------\n");
				}
				
				#set sentdate to start of day
				#so that we can set the start/end of the event accordingly
				$eventStart = $parsedDate;
				
				if ($eventStart)
				{
					EventTimeParse($dateTime, \$eventStart, \$eventDuration, $datediff{$$timeZoneField});
				}				
			}
			else
			{				
				#replace any invalid characters
				$eventTrigger =~ s/(st[\s,]+|th[\s,]+|nd[\s,]+|rd[\s,]+)|[-\s,\.]+/-/ig;
					
				DebugPrint("->STRIPPED:$eventTrigger<-\n");

				my $parsePattern;
				
				if ($eventTrigger =~ m/\b\d{2,4}-$monthNumber-\d{1,2}\b/i)	#this would match 06-04-02 or 2006-04-02
				{
					DebugPrint("->year-month(number)-day<-\n");
					
					#if year is 2 digit format
					if ($eventTrigger =~ m/\b\d{2}-$monthNumber-\d{1,2}\b/i)
					{
						$parsePattern = '%y-%m-%d';
						
					}
					elsif ($eventTrigger =~ m/\b\d{4}-$monthNumber-\d{1,2}\b/i)
					{
						$parsePattern = '%Y-%m-%d';
					}
				}
				elsif ($eventTrigger =~ m/\b\w+-\d{1,2}-\d{2,4}\b/i)	#this would match April-02-06 or April-02-2006
				{
					DebugPrint("->month(text)-day-year<-\n");
					
					#if year is 2 digit format
					if ($eventTrigger =~ m/\b\w+-\d{1,2}-\d{2}\b/i)
					{
						#if abbreviated (eg Apr.)
						if ($monthName =~ m/\.$/i)
						{							
							$parsePattern = '%b-%d-%y';
						}
						else
						{
							$parsePattern = '%B-%d-%y';
						}
						
					}
					elsif ($eventTrigger =~ m/\b\w+-\d{1,2}-\d{4}\b/i)
					{
						#if abbreviated (eg Apr.)
						if ($monthName =~ m/\.$/i)
						{							
							$parsePattern = '%b-%d-%Y';
						}
						else
						{
							$parsePattern = '%B-%d-%Y';
						}
					}
				}
				elsif ($eventTrigger =~ m/\b\d{1,2}-\w+-\d{2,4}\b/i)		#this would match 02-April-06 or 02-April-2006
				{
					DebugPrint("->day-month(text)-year<-\n");
					
					#if year is 2 digit format
					if ($eventTrigger =~ m/\b\d{1,2}-\w+-\d{2}\b/i)
					{
						DebugPrint("->2digityear<-\n");
						
						#if abbreviated (eg Apr.)
						if ($monthName =~ m/\.$/i)
						{							
							$parsePattern = '%d-%b-%y';
						}
						else
						{
							$parsePattern = '%d-%B-%y';
						}
						
					}
					elsif ($eventTrigger =~ m/\b\d{1,2}-\w+-\d{4}\b/i)
					{
						DebugPrint("->4digityear<-\n");
						
						#if abbreviated (eg Apr.)
						if ($monthName =~ m/\.$/i)
						{							
							$parsePattern = '%d-%b-%Y';
						}
						else
						{
							$parsePattern = '%d-%B-%Y';
						}
					}
				}
				elsif ($eventTrigger =~ m/\b\d{1,2}-\w+|\w+\d{1,2}\b/i)	#this would match April-02 or 02-April
				{
					DebugPrint("->day-month(text)|month(text)-day<-\n");
					
					#if day-month
					if ($eventTrigger =~ m/\b\d{1,2}-\w+\b/i)
					{
						#if abbreviated (eg Apr.)
						if ($monthName =~ m/\.$/i)
						{							
							$parsePattern = '%d-%b-%Y';
						}
						else
						{
							$parsePattern = '%d-%B-%Y';
						}						
					}
					elsif ($eventTrigger =~ m/\b\w+\d{1,2}\b/i)
					{
						#if abbreviated (eg Apr.)
						if ($monthName =~ m/\.$/i)
						{							
							$parsePattern = '%b-%d-%Y';
						}
						else
						{
							$parsePattern = '%B-%d-%Y';
						}
					}
					
					#append current year
					$eventTrigger .= "-$YEAR";
				}
				
				DebugPrint("->$parsePattern<-\n");
				
				#convert to a friendly format based on input
				#allow errors
				my $parsedDate;
				eval { $parsedDate = Time::Piece->strptime($eventTrigger, $parsePattern); };
				if($@) {
					#strip newline
					chomp $@;
					
					# print error
					ReportPrint("-------------------\n");
					ReportPrint("->ERROR:$@<-\n");
					ReportPrint("->PATTERN:$parsePattern<-\n");
					ReportPrint("-------------------\n");
				}
				
				#set sentdate to start of day
				#so that we can set the start/end of the event accordingly
				$eventStart = $parsedDate;
			}
		
			if ($eventStart)
			{
				#check eventtype
				if ($eventType eq "datetime")			
				{
					my $eventStartFormat = $eventStart->strftime("%Y-%m-%dT%H:%M:%S.00Z");
					my $eventEndFormat = ($eventStart + $eventDuration)->strftime("%Y-%m-%dT%H:%M:%S.00Z");
					
					ReportPrint("->OFFSET:" . $eventStart->tzoffset . "<-\n");
					
					EventAppend($events, $$eventKey, "start", "datetime", $eventStartFormat);
					EventAppend($events, $$eventKey, "start", "timezone", $$timeZoneField);
					EventAppend($events, $$eventKey, "end", "datetime", $eventEndFormat);
					EventAppend($events, $$eventKey, "end", "timezone", $$timeZoneField);
					$$eventKey++;
				}
				else
				{
					my $eventStartFormat = $eventStart->strftime("%Y-%m-%d");
					my $eventEndFormat = ($eventStart + $eventDuration)->strftime("%Y-%m-%d");
					
					EventAppend($events, $$eventKey, "start", "date", $eventStartFormat);
					EventAppend($events, $$eventKey, "start", "timezone", $$timeZoneField);
					EventAppend($events, $$eventKey, "end", "date", $eventEndFormat);
					EventAppend($events, $$eventKey, "end", "timezone", $$timeZoneField);
					$$eventKey++;
				}
			}
		}
	}
	
	ReportPrint("-------------------\n");
}

sub EventTimeProcess {
	
	my $events = shift;
	my $eventKey = shift;
	my $sentField = shift;
	my $contentField = shift;
	my $timeTypeField = shift;
	my $timeZoneField = shift;
	my $relativeTerm = shift;

	DebugPrint("->EventTimeProcess()<-\n");

	ReportPrint("-------------------\n");
	ReportPrint("->EVENTTIMEPROCESS()<-\n");

	#strip spaces/specific characters
	$$sentField =~ s/\s+|T+|-+|:+|.00Z+//g;
	
	#convert to a friendly format (inclusive of day)
	my $sentDate = Time::Piece->strptime($$sentField, "%Y%m%d%H%M%S");
	
	#default as a date (datetime if time specified)
	my $eventType = "date";
	
	#default duration for day = 1 day (86400 seconds)
	my $eventDuration = ONE_DAY;
	my $eventStart;

	#store copy and replace pattern
	my $usePattern = join('|', @timePattern);
	$usePattern =~ s/\$/$relativeTerm/g;
	
	DebugPrint("->$usePattern<-\n");
	
	#each result found with pattern					
	my @daytimeSeek = $$contentField =~ m/$usePattern/ig;
	
	foreach my $eventTrigger (@daytimeSeek)
	{
		if (not $eventTrigger) { next; }
		
		#DebugPrint("->$eventTrigger<-\n");
		
		ReportPrint("->EXTRACTED:$eventTrigger<-\n");										
		
		DebugPrint("->$eventTrigger|$$contentField<-\n");
		
		$$contentField =~ s/$eventTrigger//;	
		
		DebugPrint("->$eventTrigger|$$contentField<-\n");
		
		#strip day from result
		$eventTrigger =~ s/$relativeTerm(?: at | between |\s)//ig;

		#strip leading and trailing whitespaces
		$eventTrigger =~ s/^\s*|\s*$//g;
		
		DebugPrint("->STRIPPED:$eventTrigger<-\n");
		
		#if the $eventTrigger is valid (should be a time only)
		if ($eventTrigger =~ m/(?:\d{1,2}|\d{1,2}:\d{2})(?:\s[pa]m|[pa]m)?(?:[-\s~]{1,3}(?:\d{1,2}|\d{1,2}:\d{2})?(?:\s[pa]m|[pa]m))?/i)
		{
			#set as datetime (as time/duration specified)
			$eventType = "datetime";
			
			#set sentdate to start of day
			#so that we can set the start/end of the event accordingly
			$eventStart = $sentDate;
			$eventStart -= ($eventStart->hour * 60 * 60);
			$eventStart -= ($eventStart->minute * 60);
			$eventStart -= $eventStart->second;
			
			#set event start			
			if ($relativeTerm eq "tomorrow")
			{
				$eventStart += ONE_DAY * 1;
			}
			
			#default duration for time = 1 hour (3600 seconds)
			$eventDuration = 3600;
			
			EventTimeParse($eventTrigger, \$eventStart, \$eventDuration, $datediff{$$timeZoneField});
		}
		else
		{
			#if the $relativeTerm is today, then we set rest of the day as possible remainder
			if ($relativeTerm eq "today")
			{
				#set sentdate but maintain current time (as event will be remainder
				#so that we can set the start/end of the event accordingly
				$eventStart = $sentDate;

				#set duration to be remainder of the day
				#note: should match 11:59pm that day
				$eventDuration -= ($eventStart->hour * (60 * 60));
				$eventDuration -= ($eventStart->minute * 60);
				$eventDuration -= ($eventStart->second);
			}
			
			#set event start			
			if ($relativeTerm eq "tomorrow")
			{
				#set sentdate to start of day
				#so that we can set the start/end of the event accordingly
				#then add 1 day as event is tomorrow
				$eventStart = $sentDate;
				$eventStart -= ($eventStart->hour * (60 * 60));
				$eventStart -= ($eventStart->minute * 60);
				$eventStart -= $eventStart->second;
				$eventStart += ONE_DAY * 1;
			}
		}
	
		#check eventtype
		if ($eventType eq "datetime")			
		{
			my $eventStartFormat = $eventStart->strftime("%Y-%m-%dT%H:%M:%S.00Z");
			my $eventEndFormat = ($eventStart + $eventDuration)->strftime("%Y-%m-%dT%H:%M:%S.00Z");
			
			EventAppend($events, $$eventKey, "start", "datetime", $eventStartFormat);
			EventAppend($events, $$eventKey, "start", "timezone", $$timeZoneField);
			EventAppend($events, $$eventKey, "end", "datetime", $eventEndFormat);
			EventAppend($events, $$eventKey, "end", "timezone", $$timeZoneField);
			$$eventKey++;
		}
		else
		{
			my $eventStartFormat = $eventStart->strftime("%Y-%m-%d");
			my $eventEndFormat = ($eventStart + $eventDuration)->strftime("%Y-%m-%d");
			
			EventAppend($events, $$eventKey, "start", "date", $eventStartFormat);
			EventAppend($events, $$eventKey, "start", "timezone", $$timeZoneField);
			EventAppend($events, $$eventKey, "end", "date", $eventEndFormat);
			EventAppend($events, $$eventKey, "end", "timezone", $$timeZoneField);
			$$eventKey++;
		}
	}
	
	#check if any remainders
	if ($$contentField =~ m/$relativeTerm/i)
	{
		ReportPrint("->REMAINDER:$relativeTerm<-\n");
		
		#if the $relativeTerm is today, then we set rest of the day as possible remainder
		if ($relativeTerm eq "today")
		{
			#set sentdate but maintain current time (as event will be remainder
			#so that we can set the start/end of the event accordingly
			$eventStart = $sentDate;

			#set duration to be remainder of the day
			#note: should match 11:59pm that day
			$eventDuration -= ($eventStart->hour * (60 * 60));
			$eventDuration -= ($eventStart->minute * 60);
			$eventDuration -= ($eventStart->second);
		}
		
		#set event start			
		if ($relativeTerm eq "tomorrow")
		{
			#set sentdate to start of day
			#so that we can set the start/end of the event accordingly
			#then add 1 day as event is tomorrow
			$eventStart = $sentDate;
			$eventStart -= ($eventStart->hour * (60 * 60));
			$eventStart -= ($eventStart->minute * 60);
			$eventStart -= $eventStart->second;
			$eventStart += ONE_DAY * 1;
		}
		
		#check eventtype
		if ($eventType eq "datetime")			
		{
			my $eventStartFormat = $eventStart->strftime("%Y-%m-%dT%H:%M:%S.00Z");
			my $eventEndFormat = ($eventStart + $eventDuration)->strftime("%Y-%m-%dT%H:%M:%S.00Z");
			
			EventAppend($events, $$eventKey, "start", "datetime", $eventStartFormat);
			EventAppend($events, $$eventKey, "start", "timezone", $$timeZoneField);
			EventAppend($events, $$eventKey, "end", "datetime", $eventEndFormat);
			EventAppend($events, $$eventKey, "end", "timezone", $$timeZoneField);
			$$eventKey++;
		}
		else
		{
			my $eventStartFormat = $eventStart->strftime("%Y-%m-%d");
			my $eventEndFormat = ($eventStart + $eventDuration)->strftime("%Y-%m-%d");
			
			EventAppend($events, $$eventKey, "start", "date", $eventStartFormat);
			EventAppend($events, $$eventKey, "start", "timezone", $$timeZoneField);
			EventAppend($events, $$eventKey, "end", "date", $eventEndFormat);
			EventAppend($events, $$eventKey, "end", "timezone", $$timeZoneField);
			$$eventKey++;
		}
	}
	
	ReportPrint("-------------------\n");
}

sub EventDayTimeProcess {
	
	my $events = shift;
	my $eventKey = shift;
	my $sentField = shift;
	my $contentField = shift;
	my $timeTypeField = shift;
	my $timeZoneField = shift;
	my $relativeTerm = shift;

	DebugPrint("->EventDayTimeProcess()<-\n");

	ReportPrint("-------------------\n");
	ReportPrint("->EVENTDAYTIMEPROCESS()<-\n");

	#strip spaces/specific characters
	$$sentField =~ s/\s+|T+|-+|:+|.00Z+//g;
	
	#convert to a friendly format (inclusive of day)
	my $sentDate = Time::Piece->strptime($$sentField, "%Y%m%d%H%M%S");
	
	#default as a date (datetime if time specified)
	my $eventType = "date";
	
	#default duration = 1 hour (3600 seconds)
	my $eventDuration = 3600;
	my $eventStart;

	#attempt to discover the day (either short-hand or full-word)
	foreach my $day (keys %dayofweek)
	{		
		#store copy and replace pattern
		my $usePattern = join('|', @daytimePattern);
		$usePattern =~ s/\$/$day/g;
		
		#each result found with pattern					
		my @daytimeSeek = $$contentField =~ m/$usePattern/ig;
		
		#ReportPrint("->PATTERN:$usePattern<-\n");
		
		foreach my $eventTrigger (@daytimeSeek)
		{
			if (not $eventTrigger) { next; }
			
			DebugPrint("->$eventTrigger<-\n");
			
			ReportPrint("->EXTRACTED:$eventTrigger<-\n");										
			
			#DebugPrint("->$$contentField<-\n");
			
			$$contentField =~ s/$eventTrigger//;	
			
			#DebugPrint("->$$contentField<-\n");										
													
			#set sentdate to start of day
			#so that we can set the start/end of the event accordingly
			$eventStart = $sentDate;
			$eventStart -= ($eventStart->hour * 60 * 60);
			$eventStart -= ($eventStart->minute * 60);
			$eventStart -= $eventStart->second;

			#we set the starting date to sunday to progress further
			if ($relativeTerm eq "next")
			{
				#add days to reach sunday
				#add 1 to jump from Sunday @ 00:00 to Monday @ 00:00
				$eventStart += ONE_DAY * ((7 - $eventStart->day_of_week) + 1);
			}

			#this will automatically place it in the future
			$eventStart += ONE_DAY * (($dayofweek{$day} - $eventStart->day_of_week) % 7);
			
			#strip day from result
			$eventTrigger =~ s/$day\s|$day//ig;

			#strip leading and trailing whitespaces
			$eventTrigger =~ s/^\s*|\s*$//g;
			
			DebugPrint("->STRIPPED:$eventTrigger<-\n");
		
			#if the $eventTrigger is valid (should be a time only)
			if ($eventTrigger =~ m/(?:\d{1,2}|\d{1,2}:\d{2})(?:\s[pa]m|[pa]m)?(?:[-\s~]{1,3}(?:\d{1,2}|\d{1,2}:\d{2})?(?:\s[pa]m|[pa]m))?/i)
			{			
				#set as datetime (as time/duration specified)
				$eventType = "datetime";
					
				EventTimeParse($eventTrigger, \$eventStart, \$eventDuration, $datediff{$$timeZoneField});
			}			
		
			#check eventtype
			if ($eventType eq "datetime")			
			{
				my $eventStartFormat = $eventStart->strftime("%Y-%m-%dT%H:%M:%S.00Z");
				my $eventEndFormat = ($eventStart + $eventDuration)->strftime("%Y-%m-%dT%H:%M:%S.00Z");
				
				EventAppend($events, $$eventKey, "start", "datetime", $eventStartFormat);
				EventAppend($events, $$eventKey, "start", "timezone", $$timeZoneField);
				EventAppend($events, $$eventKey, "end", "datetime", $eventEndFormat);
				EventAppend($events, $$eventKey, "end", "timezone", $$timeZoneField);
				$$eventKey++;
			}
			else
			{
				my $eventStartFormat = $eventStart->strftime("%Y-%m-%d");
				my $eventEndFormat = ($eventStart + $eventDuration)->strftime("%Y-%m-%d");
				
				EventAppend($events, $$eventKey, "start", "date", $eventStartFormat);
				EventAppend($events, $$eventKey, "start", "timezone", $$timeZoneField);
				EventAppend($events, $$eventKey, "end", "date", $eventEndFormat);
				EventAppend($events, $$eventKey, "end", "timezone", $$timeZoneField);
				$$eventKey++;
			}
		}
	}
	
	ReportPrint("-------------------\n");
}

sub EventTimeParse {
	
	my $eventTrigger = shift;
	my $eventStart = shift;
	my $eventDuration = shift;
	my $dateDiff = shift;
	
	ReportPrint("->DATEDIFF:$dateDiff<-\n");
	
	ReportPrint("->UTC:$$eventStart<-\n");
	
	$$eventStart -= $dateDiff;
	
	ReportPrint("->LOCAL:$$eventStart<-\n");
	
	if ($eventTrigger =~ m/(?:\d{1,2}|\d{1,2}:\d{2})(?:\s[pa]m|[pa]m)(?:[-\s~]{1,3}(?:\d{1,2}|\d{1,2}:\d{2})(?:\s[pa]m|[pa]m))?/i)	#check for 12 hour time with the am/pm (spacing allowed) with/without range
	{
		DebugPrint("->IS 12 HOUR TIME<-\n");
		
		#check for duration						
		if ($eventTrigger =~ m/\d{1,2}(?:\:\d{2}\s?[pa]m|\s?[pa]m)?[-\s~]{1,3}?\d{1,2}(?:\:\d{2}\s?[pa]m|\s?[pa]m)/i)
		{
			DebugPrint("->IS 12 HOUR TIME WITH DURATION<-\n");
			
			#strip allowed spacing and replace with pre-determined -
			$eventTrigger =~ s/[-\s~]{1,3}/-/g;
			
			DebugPrint("->CLEANSPLIT:$eventTrigger<-\n");
			
			(my $seekStart, my $seekEnd) = split(/-/, $eventTrigger);
			
			#if the starting time is missing am/pm
			#we repair/assume range
			if ($seekStart =~ m/\d{1,2}$/ix && $seekEnd =~ m/am$/ix)
			{
				$seekStart .=  "am";
			}
			elsif ($seekStart =~ m/\d{1,2}$/ix && $seekEnd =~ m/pm$/ix)
			{
				$seekStart .=  "pm";
			}
			
			DebugPrint("->FIXED:$seekStart-$seekEnd<-\n");
			
			#if event is am, elsif pm
			if ($seekStart =~ m/am$/ix && $seekEnd =~ m/am$/ix)
			{
				#strip am
				$seekStart =~ s/am//ig;
				$seekEnd =~ s/am//ig;
				
				(my $startHour, my $startMinute);
				(my $endHour, my $endMinute);
				
				#if time is precise (eg 4:30)
				if ($seekStart =~ m/\d{1,2}:\d{2}/ix)
				{
					($startHour, $startMinute) = split(/:/, $seekStart);
				}
				else
				{
					($startHour, $startMinute) = ($seekStart, 0);
				}
				
				#if time is precise (eg 4:30)
				if ($seekEnd =~ m/\d{1,2}:\d{2}/ix)
				{
					($endHour, $endMinute) = split(/:/, $seekEnd);
				}
				else
				{
					($endHour, $endMinute) = ($seekEnd, 0);
				}
				
				#if the hour == 12 (aka 0 in real time)
				if ($startHour == 12)
				{
					$startHour -= 12;
				}
				
				#if the hour == 12 (aka 0 in real time)
				if ($endHour == 12)
				{
					$endHour -= 12;
				}
				
				#add hours and minutes
				$$eventStart += ($startHour * (60 * 60));
				$$eventStart += ($startMinute * 60);
				
				#set duration
				$$eventDuration = (($endHour - $startHour) * (60 * 60));
				
				#if endminute < startminute
				#we minus from duration rather than add
				if ($endMinute < $startMinute)
				{
					$$eventDuration -= ((abs($endMinute - $startMinute))  * 60);
				}
				else
				{
					$$eventDuration += ((abs($endMinute - $startMinute))  * 60);
				}
			}
			elsif ($seekStart =~ m/pm$/ix && $seekEnd =~ m/pm$/ix)
			{
				#strip am
				$seekStart =~ s/pm//ig;
				$seekEnd =~ s/pm//ig;
				
				(my $startHour, my $startMinute);
				(my $endHour, my $endMinute);
				
				#if time is precise (eg 4:30)
				if ($seekStart =~ m/\d{1,2}:\d{2}/ix)
				{
					($startHour, $startMinute) = split(/:/, $seekStart);
					if ($startHour != 12)
					{
						$startHour += 12;
					}
				}
				else
				{
					($startHour, $startMinute) = ($seekStart, 0);
					if ($startHour != 12)
					{
						$startHour += 12;
					}
				}
				
				#if time is precise (eg 4:30)
				if ($seekEnd =~ m/\d{1,2}:\d{2}/ix)
				{
					($endHour, $endMinute) = split(/:/, $seekEnd);
					if ($endHour != 12)
					{
						$endHour += 12;
					}
				}
				else
				{
					($endHour, $endMinute) = ($seekEnd, 0);
					if ($endHour != 12)
					{
						$endHour += 12;
					}
				}
				
				#add hours and minutes
				$$eventStart += ($startHour * (60 * 60));
				$$eventStart += ($startMinute * 60);
				
				#set duration
				$$eventDuration = (($endHour - $startHour) * (60 * 60));

				#if endminute < startminute
				#we minus from duration rather than add
				if ($endMinute < $startMinute)
				{
					$$eventDuration -= ((abs($endMinute - $startMinute))  * 60);
				}
				else
				{
					$$eventDuration += ((abs($endMinute - $startMinute))  * 60);
				}
			}
			elsif ($seekStart =~ m/am$/ix && $seekEnd =~ m/pm$/ix)
			{
				#strip am
				$seekStart =~ s/am//ig;
				$seekEnd =~ s/pm//ig;
				
				(my $startHour, my $startMinute);
				(my $endHour, my $endMinute);
				
				#if time is precise (eg 4:30)
				if ($seekStart =~ m/\d{1,2}:\d{2}/ix)
				{
					($startHour, $startMinute) = split(/:/, $seekStart);
				}
				else
				{
					($startHour, $startMinute) = ($seekStart, 0);
				}
				
				#if time is precise (eg 4:30)
				if ($seekEnd =~ m/\d{1,2}:\d{2}/ix)
				{
					($endHour, $endMinute) = split(/:/, $seekEnd);
					if ($endHour != 12)
					{
						$endHour += 12;
					}
				}
				else
				{
					($endHour, $endMinute) = ($seekEnd, 0);
					if ($endHour != 12)
					{
						$endHour += 12;
					}
				}
				
				#if the hour == 12 (aka 0 in real time)
				if ($startHour == 12)
				{
					$startHour -= 12;
				}
				
				#add hours and minutes
				$$eventStart += ($startHour * (60 * 60));
				$$eventStart += ($startMinute * 60);
				
				#set duration
				$$eventDuration = (($endHour - $startHour) * (60 * 60));

				#if endminute < startminute
				#we minus from duration rather than add
				if ($endMinute < $startMinute)
				{
					$$eventDuration -= ((abs($endMinute - $startMinute))  * 60);
				}
				else
				{
					$$eventDuration += ((abs($endMinute - $startMinute))  * 60);
				}
			}
			elsif ($seekStart =~ m/pm$/ix && $seekEnd =~ m/am$/ix)
			{
				#strip am
				$seekStart =~ s/pm//ig;
				$seekEnd =~ s/am//ig;
				
				(my $startHour, my $startMinute);
				(my $endHour, my $endMinute);
				
				#if time is precise (eg 4:30)
				if ($seekStart =~ m/\d{1,2}:\d{2}/ix)
				{
					($startHour, $startMinute) = split(/:/, $seekStart);
					if ($startHour != 12)
					{
						$startHour += 12;
					}
				}
				else
				{
					($startHour, $startMinute) = ($seekStart, 0);
					if ($startHour != 12)
					{
						$startHour += 12;
					}
				}
				
				#if time is precise (eg 4:30)
				if ($seekEnd =~ m/\d{1,2}:\d{2}/ix)
				{
					($endHour, $endMinute) = split(/:/, $seekEnd);
				}
				else
				{
					($endHour, $endMinute) = ($seekEnd, 0);
				}
				
				#if the hour == 12 (aka 0 in real time)
				if ($startHour == 12)
				{
					$startHour -= 12;
				}
				
				#add hours and minutes
				$$eventStart += ($startHour * (60 * 60));
				$$eventStart += ($startMinute * 60);
				
				#set duration
				$$eventDuration = (($endHour - $startHour) * (60 * 60));

				#if endminute < startminute
				#we minus from duration rather than add
				if ($endMinute < $startMinute)
				{
					$$eventDuration -= ((abs($endMinute - $startMinute))  * 60);
				}
				else
				{
					$$eventDuration += ((abs($endMinute - $startMinute))  * 60);
				}
			}
			
			DebugPrint("->$$eventStart|$$eventDuration<-\n");
		}
		else
		{
			DebugPrint("->IS 12 HOUR TIME WITHOUT DURATION<-\n");
			
			my $seekTime = join("-", $eventTrigger =~ m/(?:\d{1,2}|\d{1,2}:\d{2})(?:\s[pa]m|[pa]m)/ig);
			
			#strip spaces
			$seekTime =~ s/\s//g;
			
			DebugPrint("->CLEANSPLIT:$seekTime<-\n");
			
			#if event is am, elsif pm
			if ($seekTime =~ m/am$/ix)
			{
				#strip am
				$seekTime =~ s/am//ig;
				
				#if time is precise (eg 4:30)
				if ($seekTime =~ m/\d{1,2}:\d{2}/ix)
				{
					(my $seekHour, my $seekMinute) = split(/:/, $seekTime);

					#add hours and minutes to time
					$$eventStart += ($seekHour * (60 * 60));
					$$eventStart += ($seekMinute * 60);
				}
				else
				{
					my $seekHour = $seekTime;

					#add hours and minutes to time
					$$eventStart += ($seekHour * (60 * 60));
				}
			}
			elsif ($seekTime =~ m/pm$/ix)
			{
				#strip pm
				$seekTime =~ s/pm//ig;
				
				#if time is precise (eg 4:30)
				if ($seekTime =~ m/\d{1,2}:\d{2}/ix)
				{
					(my $seekHour, my $seekMinute) = split(/:/, $seekTime);

					if ($seekHour == 12)
					{
						#add only the 12 since its noon
						$$eventStart += ($seekHour * (60 * 60));
					}
					else
					{
						#add 12 to the number (eg 1pm = 12 + 1 = 13:00 in 24 hour time)
						$$eventStart += (($seekHour + 12) * (60 * 60));
					}

					#add minutes
					$$eventStart += ($seekMinute * 60);
				}
				else
				{
					my $seekHour = $seekTime;

					if ($seekHour == 12)
					{
						#add only the 12 since its noon
						$$eventStart += ($seekHour * (60 * 60));
					}
					else
					{
						#add 12 to the number (eg 1pm = 12 + 1 = 13:00 in 24 hour time)
						$$eventStart += (($seekHour + 12) * (60 * 60));
					}
				}
			}
			
			DebugPrint("->$$eventStart<-\n");
		}
	}
	elsif ($eventTrigger =~ m/\d{2}:\d{2}(?:[-\s~]{1,3}\d{2}:\d{2})?/i)	#check for 24 hour time (spacing allowed) with/without range
	{
		DebugPrint("->IS 24 HOUR TIME<-\n");
		
		DebugPrint("->$eventTrigger<-\n");
		
		if ($eventTrigger =~ /\d{2}:\d{2}(?:[-\s~]{1,3}\d{2}:\d{2})/i)
		{
			DebugPrint("->IS 24 HOUR TIME WITH DURATION<-\n");
			
			#strip allowed spacing and replace with pre-determined -
			$eventTrigger =~ s/[-\s~]{1,3}/-/g;
			
			#split to split range
			(my $seekStart, my $seekEnd) = split(/-/, $eventTrigger);
														
			(my $startHour, my $startMinute);
			(my $endHour, my $endMinute);
			
			#split starting time by colon
			($startHour, $startMinute) = split(/:/, $seekStart);
			
			#split ending time by colon
			($endHour, $endMinute) = split(/:/, $seekEnd);

			#add hours and minutes
			$$eventStart += ($startHour * (60 * 60));
			$$eventStart += ($startMinute * 60);

			#set duration from hours
			$$eventDuration = (($endHour - $startHour) * (60 * 60));
			
			
			#if endminute < startminute
			#we minus from duration rather than add
			if ($endMinute < $startMinute)
			{
				$$eventDuration -= ((abs($endMinute - $startMinute))  * 60);
			}
			else
			{
				$$eventDuration += ((abs($endMinute - $startMinute))  * 60);
			}

			DebugPrint("->$$eventStart|$$eventDuration<-\n");
		}
		else
		{
			DebugPrint("->IS 24 HOUR TIME WITHOUT DURATION<-\n");
			
			(my $seekHour, my $seekMinute) = split(/:/, $eventTrigger);

			#add hours and minutes
			$$eventStart += ($seekHour * (60 * 60));
			$$eventStart += ($seekMinute * 60);
			
			DebugPrint("->$$eventStart<-\n");
		}
	}
}

sub EventAppend {
	my $events = shift;
	my $eventKey = shift;
	my $section = shift;
	my $key = shift;
	my $value = shift;
	
	$$events[$eventKey]->{$section}->{$key} = $value;
}

sub EventPrinter {
	my $events = shift;
	
	print "Number of events: ";
	print (scalar @$events);
	print "\n---------------------------------------------------------\n";
	for (my $i = 0; $i < (scalar @$events); $i++) 
	{
		my $event = $$events[$i];
		if ($event) 
		{
			my $startSection = $event->{'start'};
			
			print "$i->START\n";
		
			foreach my $key (keys $startSection)
			{				
				print "$i->" . $key . " : " . $$startSection{$key} . "\n";
			}
		
			print "\n";
			
			my $endSection = $event->{'end'};
			
			print "$i->END\n";
		
			foreach my $key (keys $endSection)
			{				
				print "$i->" . $key . " : " . $$endSection{$key} . "\n";
			}
		
			print "---------------------------------------------------------\n";			
		}
		
	}
}

sub EmailStructBuilder {
	my $emails = $_[0];
	my $emailKey = $_[1];
	my $key = $_[2];
	my $value = $_[3];
	
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
		# increment struct key
		# and add shell
		$$emailKey++;
		$$emails[$$emailKey]->{'timeType'} = "date";
		$$emails[$$emailKey]->{'timeZone'} = "Australia/Melbourne";	#defualt to local
	}
	
	# if timeZone key specified, we change email type
	# to datetime as the event has time-specific
	if ($key eq "timeZone") {
		# if timeZone specified
		# modify shell
		$$emails[$$emailKey]->{'timeType'} = "datetime";
		$$emails[$$emailKey]->{'timeZone'} = "Australia/Melbourne";	#defualt to local
	}
	
	# dereference to access hash
	# and add key/value
	$$emails[$$emailKey]->{$key} = $value;
}

sub KeyValueExtractor {
	
	#assign variable
	my $string = shift;
	
	#strip leading and trailing whitespaces
	$string =~ s/^\s*|\s*$//g;
	
	#strip spacing betweek key/value
	$string =~ s/"\s*:/":/g;
	$string =~ s/:\s*"/:"/g;

	#seek for key/value pairs = eg "timeZone":"Australia/Melbourne" or "timestamp":1497895235
	my @found = $string =~ m/"(.*?)":"(.*?)"|"(.*?)":(\d+)/ig;
	
	#group to only defined entries
	return grep defined, @found;
}

sub EmailPrinter {	

	my $emails = shift;
	
	print "Number of emails: ";
	print (scalar @$emails);
	print "\n-------------------\n";
	for (my $i = 0; $i < (scalar @$emails); $i++) 
	{
		my $hash = $$emails[$i];
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
}

sub PrintOutput {
	my $events = shift;
	my $outputFile = shift;
	
	open my $file,">$outputFile" or die "Could not print to $outputFile.\n";
	
	print $file "[\n";
	
	#goes to each event
	for (my $i = 0; $i < (scalar @$events); $i++) 
	{
		
		my $event = $$events[$i];
		if ($event) 
		{
			my $startSection = $event->{'start'};
			print $file "  {\n    \"start\" : {\n      ";
			
			my $count = 0;
			
			if(exists($$startSection{datetime}))
			{
				print $file "\"datetime\":  \"$$startSection{datetime}\",\n      ";
				print $file "\"timezone\":  \"$$startSection{timezone}\"\n    },\n";
			}
			else 
			{
				print $file "\"timezone\":  \"$$startSection{timezone}\",\n      ";
				print $file "\"date\":  \"$$startSection{date}\"\n    },\n";
			}
			
			print $file "    \"end\" : {\n      ";
			my $endSection = $event->{'end'};
			
			if(exists($$startSection{datetime}))
			{
				print $file "\"datetime\":  \"$$endSection{datetime}\",\n      ";
				print $file "\"timezone\":  \"$$endSection{timezone}\"\n    }\n";
			}
			else 
			{
				print $file "\"timezone\":  \"$$endSection{timezone}\",\n      ";
				print $file "\"date\":  \"$$endSection{date}\"\n    }\n";
			}
			
			$count = 0;
		
				
		}
		print $file "  },\n";
	
	}
	
	print $file "]";

	close $file;
	
	
}

sub DebugPrint {
	return;
	print shift;
}

sub ReportPrint {

	print shift;
}

# return true for module
1;