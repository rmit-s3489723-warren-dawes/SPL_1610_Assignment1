#!/usr/bin/env perl
package EventExtractor;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(DebugPrint KeyValueExtractor EmailStructBuilder EmailPrinter EmailContentParser);

use strict;
use warnings;

use LWP::Simple;

use POSIX;
use Time::Local;
use Time::Seconds;
use Time::Piece ':override';

use Date::Parse;
use Date::Format 'time2str';

use Data::Dumper;

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
	'$\s?\d{1,2}(?:\:\d{2}\s?[pa]m|\s?[pa]m|\:\d{2})(?:[-\s~]{1,3}?\d{1,2}(?:\:\d{2}\s?[pa]m|\s?[pa]m|\:\d{2}))?',				
);

#patterns are joined together with an | operator (or clause)
#eg join('|', @timePattern)
my @timePattern = 
(
	#pattern for time with range = eg today 4pm or today at 4pm or today 4pm - 6pm or today between 4pm - 6pm (allows for precise time - 4:00pm etc)
	'$(?: at | between |\s)\d{1,2}(?:\:\d{2}\s?[pa]m|\s?[pa]m|\:\d{2})(?:[-\s~]{1,3}?\d{1,2}(?:\:\d{2}\s?[pa]m|\s?[pa]m|\:\d{2}))?',	
);

my @datePattern = 
{
	'\d{1,2} $ \d{2,4}',	#regex does some shit aka day (1 or 2 digit) + month + year (2 or 4 digit) = 20 April 2006
}

#[month/date]or[date/month] = 19 April or April 19 or 19th April or April 19th
#[time with am/pm or colon] = 4pm or 4:30pm or 14:00 -> \d{1,2}(?:\:\d{2}\s?[pa]m|\s?[pa]m|\:\d{2})(?:[-\s~]{1,3}?\d{1,2}(?:\:\d{2}\s?[pa]m|\s?[pa]m|\:\d{2}))?
#[year] = 98 or 1998


my %datediff = ('Australia/Melbourne' => 0);

=pod

=head2 EmailContentParser(\@emails)

\@emails is a reference to the emails array that contains the structure.

=cut

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
			
			if ($emailKey > 0) #&& $emailKey <= 3)
			{								
				#iterate for relative seek
				foreach my $relativeTerm (keys %relativeSeek)
				{
					#foreach identified seek
					foreach my $rsMatch ($contentField =~ m/$relativeTerm+/g)
					{
						print "$rsMatch\n";
						
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

sub EventTimeProcess {
	
	my $events = shift;
	my $eventKey = shift;
	my $sentField = shift;
	my $contentField = shift;
	my $timeTypeField = shift;
	my $timeZoneField = shift;
	my $relativeTerm = shift;

	#strip spaces/specific characters
	$$sentField =~ s/\s+|T+|-+|:+|.00Z+//g;
	
	#convert to a friendly format (inclusive of day)
	my $sentDate = Time::Piece->strptime($$sentField, "%Y%m%d%H%M%S");
	
	#default duration = 1 hour (3600 seconds)
	my $eventDuration = 3600;
	my $eventStart = $sentDate;

	#attempt to discover the day (either short-hand or full-word)
	foreach my $day (keys %dayofweek)
	{
		#store copy and replace pattern
		my $usePattern = join('|', @timePattern);
		$usePattern =~ s/\$/$relativeTerm/g;
		
		DebugPrint("->$usePattern<-\n");
		
		#each result found with pattern					
		my @daytimeSeek = $$contentField =~ m/$usePattern/ig;
		
		foreach my $eventTrigger (@daytimeSeek)
		{
			if (not $eventTrigger) { next; }
			
			DebugPrint("->$eventTrigger<-\n");										
			
			DebugPrint("->$$contentField<-\n");
			
			$$contentField =~ s/$eventTrigger//;	
			
			DebugPrint("->$$contentField<-\n");
												
			#set sentdate to start of day
			#so that we can set the start/end of the event accordingly
			$eventStart -= ($eventStart->hour * 60 * 60);
			$eventStart -= ($eventStart->minute * 60);
			$eventStart -= $eventStart->second;
			
			#assign days of the week
			my $triggerDOW = $dayofweek{$day};
			my $eventStartDOW = $eventStart->day_of_week;			
			
			DebugPrint("->$triggerDOW|$eventStartDOW<-\n");
			
			#set event start			
			if ($relativeTerm eq "tomorrow")
			{
				$eventStart += ONE_DAY * 1;
			}			
			
			#strip day from result
			$eventTrigger =~ s/$relativeTerm at |$relativeTerm between |$relativeTerm\s|$relativeTerm//ig;

			#strip leading and trailing whitespaces
			$eventTrigger =~ s/^\s*|\s*$//g;

			EventTimeParse($eventTrigger, \$eventStart, \$eventDuration);
		
			my $eventStartFormat = $eventStart->strftime("%Y-%m-%dT%H:%M:%S.00Z");
			my $eventEndFormat = ($eventStart + $eventDuration)->strftime("%Y-%m-%dT%H:%M:%S.00Z");
			
			EventAppend($events, $$eventKey, "start", "datetime", $eventStartFormat);
			EventAppend($events, $$eventKey, "start", "timezone", $$timeZoneField);
			EventAppend($events, $$eventKey, "end", "datetime", $eventEndFormat);
			EventAppend($events, $$eventKey, "end", "timezone", $$timeZoneField);
			$$eventKey++;
		}
	}
}

sub EventDayTimeProcess {
	
	my $events = shift;
	my $eventKey = shift;
	my $sentField = shift;
	my $contentField = shift;
	my $timeTypeField = shift;
	my $timeZoneField = shift;
	my $relativeTerm = shift;

	#strip spaces/specific characters
	$$sentField =~ s/\s+|T+|-+|:+|.00Z+//g;
	
	#convert to a friendly format (inclusive of day)
	my $sentDate = Time::Piece->strptime($$sentField, "%Y%m%d%H%M%S");
	
	#default duration = 1 hour (3600 seconds)
	my $eventDuration = 3600;
	my $eventStart = $sentDate;

	#attempt to discover the day (either short-hand or full-word)
	foreach my $day (keys %dayofweek)
	{
		#store copy and replace pattern
		my $usePattern = join('|', @daytimePattern);
		$usePattern =~ s/\$/$day/g;
		
		#each result found with pattern					
		my @daytimeSeek = $$contentField =~ m/$usePattern/ig;
		
		foreach my $eventTrigger (@daytimeSeek)
		{
			if (not $eventTrigger) { next; }
			
			DebugPrint("->$eventTrigger<-\n");										
			
			DebugPrint("->$$contentField<-\n");
			
			$$contentField =~ s/$eventTrigger//;	
			
			DebugPrint("->$$contentField<-\n");										
													
			#set sentdate to start of day
			#so that we can set the start/end of the event accordingly
			$eventStart -= ($eventStart->hour * 60 * 60);
			$eventStart -= ($eventStart->minute * 60);
			$eventStart -= $eventStart->second;
			
			#assign days of the week
			my $triggerDOW = $dayofweek{$day};
			my $eventStartDOW = $eventStart->day_of_week;			
			
			DebugPrint("->$triggerDOW|$eventStartDOW<-\n");
			
			#set event start
			$eventStart += ONE_DAY * (($triggerDOW - $eventStartDOW) % 7);
			
			#strip day from result
			$eventTrigger =~ s/$day\s|$day//ig;

			#strip leading and trailing whitespaces
			$eventTrigger =~ s/^\s*|\s*$//g;

			EventTimeParse($eventTrigger, \$eventStart, \$eventDuration);
		
			my $eventStartFormat = $eventStart->strftime("%Y-%m-%dT%H:%M:%S.00Z");
			my $eventEndFormat = ($eventStart + $eventDuration)->strftime("%Y-%m-%dT%H:%M:%S.00Z");
			
			EventAppend($events, $$eventKey, "start", "datetime", $eventStartFormat);
			EventAppend($events, $$eventKey, "start", "timezone", $$timeZoneField);
			EventAppend($events, $$eventKey, "end", "datetime", $eventEndFormat);
			EventAppend($events, $$eventKey, "end", "timezone", $$timeZoneField);
			$$eventKey++;
		}
	}
}

sub EventTimeParse {
	
	my $eventTrigger = shift;
	my $eventStart = shift;
	my $eventDuration = shift;
	
	if ($eventTrigger =~ m/\d{1,2}(?:\:\d{2}\s?[pa]m|\s?[pa]m)(?:[-\s~]{1,3}?\d{1,2}(?:\:\d{2}\s?[pa]m|\s?[pa]m))?/i)	#check for 12 hour time with the am/pm (spacing allowed) with/without range
	{
		DebugPrint("->IS 12 HOUR TIME<-\n");
		
		#check for duration						
		if ($eventTrigger =~ m/\d{1,2}(?:\:\d{2}\s?[pa]m|\s?[pa]m)[-\s~]{1,3}?\d{1,2}(?:\:\d{2}\s?[pa]m|\s?[pa]m)/i)
		{
			DebugPrint("->IS 12 HOUR TIME WITH DURATION<-\n");
			
			#strip allowed spacing and replace with pre-determined -
			$eventTrigger =~ s/[-\s~]{1,3}/-/g;
			
			(my $seekStart, my $seekEnd) = split(/-/, $eventTrigger);
			
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
				
				#add hours and minutes
				$$eventStart += ($startHour * (60 * 60));
				$$eventStart += ($startMinute * 60);
				
				#set duration
				$$eventDuration = (($endHour - $startHour) * (60 * 60));
				$$eventDuration += ((abs($endMinute - $startMinute))  * 60);
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
				$$eventDuration += ((abs($endMinute - $startMinute))  * 60);
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
				
				#add hours and minutes
				$$eventStart += ($startHour * (60 * 60));
				$$eventStart += ($startMinute * 60);
				
				#set duration
				$$eventDuration = (($endHour - $startHour) * (60 * 60));
				$$eventDuration += ((abs($endMinute - $startMinute))  * 60);
			}
			
			DebugPrint("->$$eventStart|$$eventDuration<-\n");
		}
		else
		{
			DebugPrint("->IS 12 HOUR TIME WITHOUT DURATION<-\n");
			
			my $seekTime = join("-", $eventTrigger =~ m/\d{1,2}(?:\:\d{2}\s?[pa]m|\s?[pa]m)/ig);
			
			#strip spaces
			$seekTime =~ s/\s//g;
			
			print "->$seekTime<-\n";
			
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
	elsif ($eventTrigger =~ m/\d{2}\:\d{2}(?:[-\s~]{1,3}?\d{2}\:\d{2})?/i)	#check for 24 hour time (spacing allowed) with/without range
	{
		DebugPrint("->IS 24 HOUR TIME<-\n");
		
		DebugPrint("->$eventTrigger\n<-");
		
		if ($eventTrigger =~ /\d{2}:\d{2}[-\s~]{1,3}?\d{2}:\d{2}/i)
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
			$eventStart += ($startHour * (60 * 60));
			$eventStart += ($startMinute * 60);
			
			#set duration
			$eventDuration = (($endHour - $startHour) * (60 * 60));
			$eventDuration += ((abs($endMinute - $startMinute))  * 60);
			
			DebugPrint("->$$eventStart|$$eventDuration<-\n");
		}
		else
		{
			DebugPrint("->IS 24 HOUR TIME WITHOUT DURATION<-\n");
			
			(my $seekHour, my $seekMinute) = split(/:/, $eventTrigger);

			if ($seekHour == 12)
			{
				#add only the 12 since its noon
				$eventStart += ($seekHour * (60 * 60));
			}
			else
			{
				#add 12 to the number (eg 1pm = 12 + 1 = 13:00 in 24 hour time)
				$eventStart += (($seekHour + 12) * (60 * 60));
			}

			#add minutes
			$eventStart += ($seekMinute * 60);
			
			DebugPrint("->$eventStart<-\n");
		}
	}
}

sub EventDateProcess{
	
	my $events = shift;
	my $eventKey = shift;
	my $sentField = shift;
	my $contentField = shift;
	my $timeTypeField = shift;
	my $timeZoneField = shift;
	my $relativeTerm = shift;
	
	#strip spaces/specific characters
	$$sentField =~ s/\s+|T+|-+|:+|.00Z+//g;  #thids makes sent field into a numbers only format ie 20160312 (24hr)
	
	#convert to a friendly format (inclusive of day)
	my $sentDate = Time::Piece->strptime($$sentField, "%Y%m%d%H%M%S");
	
	#default duration = 1 hour (3600 seconds)
	my $eventDuration = 3600; #ONE_DAY is 24 hours of seconds
	my $eventStart = $sentDate;

	#attempt to discover the month (either short-hand or full-word)
	foreach my $month (keys %monthofyear)
	{
		#store copy and replace pattern
		my $usePattern = join('|', @datePattern);
		#replace $ symbol in regex with month
		$usePattern =~ s/\$/$month/g;
		
		#each result found with pattern (which has $ replaced with month)			
		my @dateSeek = $$contentField =~ m/$usePattern/ig;
		
		foreach my $eventTrigger (@dateSeek)
		{
			if (not $eventTrigger) { next; }
			
			DebugPrint("->$eventTrigger<-\n");										
			
			DebugPrint("->$$contentField<-\n");
			
			$$contentField =~ s/$eventTrigger//;	
			
			DebugPrint("->$$contentField<-\n");										
													
			#use the date (within $eventTrigger) to assign start date
			#most likely have to do some m// here to work out if with time (eg 20 April 2006, 4pm or 20 April 2006, 4pm - 8pm)
			#then if with time, extract via EventTimeParse(); which adds to $eventStart and sets $eventDuration
			
			#at this point $eventStart must be the day/month/year of the event so far (eg April 19th 1998 @ 00:00)
			
			#strip day from result
			$eventTrigger =~ s/$month\s|$month//ig;

			#strip leading and trailing whitespaces
			$eventTrigger =~ s/^\s*|\s*$//g;

			#note: above two regex strip invalid characters
			#$eventTrigger should be just a time at this stage to be valid for EventTimeParse() (eg "4pm" or "4pm - 8pm")
			#$eventDuration should be ONE_DAY at this point, if modified then a range was supplied (eg 4pm - 8pm = $eventDuration of 4 hours in seconds)
			EventTimeParse($eventTrigger, \$eventStart, \$eventDuration);
		
			#ie 4pm - 5pm or 4pm 5pm or 4:30pm - 5:30pm or 16:00 - 19:00 = examples of $eventTrigger
			#note: EVENT TRIGGER MUST ONLY CONTAIN TIME - NO SPACES OR OTHER CHARACTERS
			my $eventStartFormat = $eventStart->strftime("%Y-%m-%dT%H:%M:%S.00Z");
			my $eventEndFormat = ($eventStart + $eventDuration)->strftime("%Y-%m-%dT%H:%M:%S.00Z");
			
			EventAppend($events, $$eventKey, "start", "datetime", $eventStartFormat);
			EventAppend($events, $$eventKey, "start", "timezone", $$timeZoneField);
			EventAppend($events, $$eventKey, "end", "datetime", $eventEndFormat);
			EventAppend($events, $$eventKey, "end", "timezone", $$timeZoneField);
			$$eventKey++;
			
			#assume theres no range of dates if there's a time its 1 hour duration, f the time has a range it is custom, if its got no time it's all day
			#Don't need to set default start time
			#need to extract day month year
			#if time is there extract it and call the evnttimeparser
			#if it's an all day  just add it to the event array
			#if it has a time as well pass it to the eventstart/end subs
			#then appened to events
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

=head2 EmailStructBuilder(\@emails, \$emailKey, $key, $value)

\@emails is the reference to the emails array, \$emailKey is the reference to the current emailKey,
$key is a string of the key from the line, $value is a string of the value from the line.

=cut

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

=pod

=head2 KeyValueExtractor() return ($key, $value)

$key is a string of the key from the line, $value is a string of the value from the line.

=cut

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

=pod

=head2 EmailPrinter(\@emails)

\@emails is a reference to the emails array that contains the structure.

=cut

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

sub DebugPrint {

	print shift;
}

# return true for module
1;