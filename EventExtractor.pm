#!/usr/bin/env perl
package EventExtractor;
use strict;
use warnings;
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
	"today" => "time",		#eg today 4pm or today 4am or today 16:00
	"tomorrow" => "time",		#eg tomorrow 4pm or tomorrow 4am or tomorrow 16:00
	
	"next" => "daytime",		#eg next Monday or next Monday 4pm or next Monday 16:00
	"fortnight" => "daytime",	#eg fortnight (^)
);

#populate with identified patterns
#my %datePatterns =
#(
#	'\b$\b.{0,20}\d+:*\d*\s*[pa]m*' => "daytime",	#eg mon 4pm or monday 4pm
#	#'\b$\b \d+:\d+|\b$\b \d+:\d+' => "time24h", 	#eg mon 23:00 or monday 23:00
#);

#case for 12 hour (with an optional colon) or 24 hour time (requires colon)
my $daytimePattern = '$\s{0,1}?\d{1,2}\s{0,1}?[pa]m[-\s]{1,3}?\d{1,2}\s{0,1}?[pa]m|$\s{0,1}?\d{1,2}:+?\d{2}\s{0,1}?[pa]*m*[-\s]{1,3}?\d{1,2}:+?\d{2}\s{0,1}?[pa]*m*|$\s{0,1}?\d{1,2}\s{0,1}?[pa]m|$\s{0,1}?\d{1,2}:+?\d{1,2}\s{0,1}?[pa]*m*';

=pod

=head2 EmailContentParser(\@emails)

\@emails is a reference to the emails array that contains the structure.

=cut

#parse data
sub EmailContentParser {
	my $emails = shift;
	my $events = shift;
	my $eventKey = shift;
	
	for (my $emailKey = 0; $emailKey < (scalar @$emails); $emailKey++)
	{
		my $email = $$emails[$emailKey];
		if ($email) 
		{
			#store fields from emails
			my $sentField = $email->{'sent'};
			my $contentField = $email->{'content'};
			my $timeTypeField = $email->{'timeType'};
			my $timeZoneField = $email->{'timeZone'};
			
			if ($emailKey == 1) #&& $emailKey <= 3)
			{				
				#remove garbage from sent field
				#strip spaces/specific characters
				$sentField =~ s/\s+|T+|-+|:+|.00Z+//g;
				
				#convert to a friendly format (inclusive of day)
				my $sentDate = Time::Piece->strptime($sentField, "%Y%m%d%H%M%S");
				
				#default duration = 1 hour (3600 seconds)
				my $eventDuration = 3600;
				my $eventStart = $sentDate;
				
				#iterate for relative seek
				foreach my $rsKey (keys %relativeSeek)
				{
					#foreach identified seek
					foreach my $rsMatch ($contentField =~ m/$rsKey+/g)
					{
						print "$rsMatch\n";
						
						#create a new shell for event
						#EventCreateShell($events, $eventKey, $timeTypeField, $timeZoneField);
						
						#if the seek type is daytime	
						if ($relativeSeek{$rsKey} eq "daytime")
						{
							#attempt to discover the day (either short-hand or full-word)
							foreach my $day (keys %dayofweek)
							{
								#store copy and replace pattern
								(my $usePattern = $daytimePattern) =~ s/\$/$day/g;
								
								#each result found with pattern					
								my @seek = $contentField =~ m/$usePattern/ig;
								
								foreach my $seekResult (@seek)
								{
									if ($seekResult)
									{
										print $usePattern . "->" . $daytimePattern . "<-\n";
										print $rsKey . "->" . $seekResult . "<-\n";										
										print $eventStart . "\n";
																					
										#set sentdate to start of day
										#so that we can set the start/end of the event accordingly
										$eventStart -= ($eventStart->hour * 60 * 60);
										$eventStart -= ($eventStart->minute * 60);
										$eventStart -= $eventStart->second;
										
										#set event start
										$eventStart += ONE_DAY * (($dayofweek{$day} - $eventStart->day_of_week) % 7);
										
										print $eventStart . "\n";
										
										if ($seekResult =~ m/ \d{2}?\s*?[pa]m/i)		#check for single number 12 hour time with the am/pm (spacing allowed)
										{
											if ($seekResult =~ m/ \d{2}?\s*?pm/i)
											{
												my $seekTime = join("", $seekResult =~ m/\d{2}?/ixg);
												if ($seekTime eq "12")
												{
													$eventStart += ($seekTime * (60 * 60));
												}
												else
												{
													$eventStart += (($seekTime + 12) * (60 * 60));
												}
												print "case is single number 12 hour time!\n->$seekTime<-\n";
											}
											elsif ($seekResult =~ m/ \d{2}?\s*?am/i)
											{
												my $seekTime = join("", $seekResult =~ m/\d{2}?/ixg);
												$eventStart += ($seekTime * (60 * 60));
												print "case is single number 12 hour time!\n->$seekTime<-\n";
											}
										}
										elsif ($seekResult =~ m/ \d{2}?:\d{2}?\s*?[pa]m/i)	#check for double number 12 hour time with the colon and am/pm (spacing allowed)
										{
											if ($seekResult =~ m/ \d{2}?:\d{2}?\s*?pm/i)
											{
												my $seekTime = join("", $seekResult =~ m/\d{2}?:\d{2}?/ixg);
												(my $seekHour, my $seekMinute) = split(/:/, $seekTime);
												print $seekHour . "->" . $seekMinute . "<-\n";
												if ($seekHour eq "12")
												{
													$eventStart += ($seekHour * (60 * 60));
												}
												else
												{
													$eventStart += (($seekHour + 12) * (60 * 60));
												}
												$eventStart += ($seekMinute * 60);
												print "case is double number 12 hour time!\n->$seekTime<-\n";
											}
											elsif ($seekResult =~ m/ \d{2}?:\d{2}?\s*?am/i)
											{
												my $seekTime = join("", $seekResult =~ m/\d{2}?:\d{2}?/ixg);
												(my $seekHour, my $seekMinute) = split(/:/, $seekTime);
												print $seekHour . "->" . $seekMinute . "<-\n";
												$eventStart += ($seekHour * (60 * 60));
												$eventStart += ($seekMinute * 60);
												print "case is double number 12 hour time!\n->$seekTime<-\n";
											}
										}
										elsif ($seekResult =~ m/ \d{2}?:\d{2}?/i)		#check for 24 hour time
										{
											my $seekTime = join("", $seekResult =~ m/\d{2}?:\d{2}?/ixg);
											(my $seekHour, my $seekMinute) = split(/:/, $seekTime);
											print $seekHour . "->" . $seekMinute . "<-\n";
											$eventStart += ($seekHour * (60 * 60));
											$eventStart += ($seekMinute * 60);
											print "case is 24 hour time!\n->$seekTime<-\n";
										}
										
										print $eventStart . "\n";
										
										#print "$seekResult\n";
										
										#my @seekTimes = $seekResult =~ m/\d+/g;
										
										#foreach my $seekTime (@seekTimes)
										#{
										#	print "$seekTime\n";
										#}
										
										#print "$seekResult\n";
									
									#my $todayDate = strftime("%Y-%m-%dT%H:%M:%S.00Z", gmtime());
									
									
										my $eventStartFormat = $eventStart->strftime("%Y-%m-%dT%H:%M:%S.00Z");
										my $eventEndFormat = ($eventStart + $eventDuration)->strftime("%Y-%m-%dT%H:%M:%S.00Z");
									
										EventAppend($events, $$eventKey, "start", "datetime", $eventStartFormat);
										EventAppend($events, $$eventKey, "start", "timezone", $timeZoneField);
										EventAppend($events, $$eventKey, "end", "datetime", $eventEndFormat);
										EventAppend($events, $$eventKey, "end", "timezone", $timeZoneField);
										$$eventKey++;
									}
								}
							}
						}
						
						#if seek type is time
						#eg today/tomorrow
						if ($relativeSeek{$rsKey} eq "time")
						{
						}
					}
				}
				
				
				
				
				
				
				
				
				
				
				
				
				
				
				
				
				
				
				
				
				
				
				#print "$sentDate\n";
				
				#$sentDate -= ($sentDate->hour * 60 * 60);
				#$sentDate -= ($sentDate->minute * 60);
				#$sentDate -= $sentDate->second;
				#$sentDate += ONE_DAY * ((1 - $sentDate->day_of_week) % 7);
				
				#$sentDate->add(days => 7); #(1 - $sentDate->day_of_week) % 7); 
				
				#print "$sentDate\n";
				
				#my $todayDate = strftime("%Y-%m-%dT%H:%M:%S.00Z", gmtime()); #eg 2016-04-09T03:51:42.00Z
				
				#print "$sentField vs $todayDate\n";
				
				#print "[$emailKey]->$contentField\n";
				
				#https://timezonedb.com/api
				#http://api.timezonedb.com/?lat=53.7833&lng=-1.75&key=EHUCC69JBOJT&format=json
			}
		}
	}
	
	EventPrinter($events);
}
#end parse data

#sub EventCreateShell {
#	my $events = shift;
#	my $eventKey = shift;
#	my $timeTypeField = shift;
#	my $timeZoneField = shift;
#	
#	#create a shell
#	$$events[++$$eventKey] =
#	{
#		"start" =>
#		{
#			"timezone" => $timeZoneField,
#			$timeTypeField => "",
#		},
#		"end" =>
#		{
#			"timezone" => $timeZoneField,
#			$timeTypeField => "",
#		},
#	};
#	
#	print "createshell->$$eventKey\n";
#}

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
	print "\n-------------------\n";
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
		
			print "-------------------\n";
			
			my $endSection = $event->{'end'};
			
			print "$i->END\n";
		
			foreach my $key (keys $endSection)
			{				
				print "$i->" . $key . " : " . $$endSection{$key} . "\n";
			}
		
			print "-------------------\n";			
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

#parse key/value for case and build structure
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
#end build

=pod

=head2 KeyValueExtractor() return ($key, $value)

$key is a string of the key from the line, $value is a string of the value from the line.

=cut

#sub to extract key/value pair
sub KeyValueExtractor {
	
	# new variables
	my @patterns = { "", "" };
	
	# if starting with double-quotes (targeted to $_)
	if(m/"(.*?)"/x)
	{
	    # extract any data within paired double-quotes
	    # and store in array to be returned
	    @patterns = /"(.*?)"/gx;
	}
	
	return @patterns;
}
#end extract

=pod

=head2 EmailPrinter(\@emails)

\@emails is a reference to the emails array that contains the structure.

=cut

#print data
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
#end print data

# return true for module
1;