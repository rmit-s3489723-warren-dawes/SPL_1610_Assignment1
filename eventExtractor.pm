#!/usr/bin/env perl
package EventExtractor;
use strict;
use warnings;
use POSIX;
use Time::Local;
use Time::Seconds;
use Time::Piece ':override';

use Date::Parse;
use Date::Format;

use Data::Dumper;


#reference for day of the week
my %dayofweek =
(
	"monday" => 1,
	"tuesday" => 2,
	"wednesday" => 3,
	"thursday" => 4,
	"friday" => 5,
	"saturday" => 6,
	"sunday" => 7,
	
	"mon" => 1,
	"tues" => 2,
	"wed" => 3,
	"thurs" => 4,
	"fri" => 5,
	"sat" => 6,
	"sun" => 7,
);

my %relativeSeek =
(
	"today" => "time",	#eg today 4pm or today 4am or today 16:00
	"tomorrow" => "time",	#eg tomorrow 4pm or tomorrow 4am or tomorrow 16:00
	
	"next" => "date",	#eg next Monday or next Monday 4pm or next Monday 16:00
	"fortnight" => "date",	#eg fortnight (^)
);

#populate with identified patterns
my %timePatterns =
(
	'\d+[pa]m' => "static_time12h", 		#eg 11pm
	'\d+:\d+' => "static_time24h", 			#eg 23:00
	'\d+[pa]m - \d+[pa]m' => "range_time12h", 	#eg 11pm - 12pm
	'\d+:\d+ - \d+:\d+' => "range_time24h", 	#eg 23:00 - 24:00
	'\d+[pa]m \d+[pa]m' => "range_time12h", 	#eg 11pm 12pm
	'\d+:\d+ \d+:\d+' => "range_time24h", 		#eg 23:00 24:00
	'\d+[pa]m to \d+[pa]m' => "range_time12h", 	#eg 11pm to 12pm
	'\d+:\d+ to \d+:\d+' => "range_time24h", 	#eg 23:00 to 24:00
);

#populate with identified patterns
my %datePatterns =
(
	'\b$\b \d+[pa]m|\b$\b \d+[pa]m' => "time12h",	#eg mon 4pm or monday 4pm
	'\b$\b \d+:\d+|\b$\b \d+:\d+' => "time24h", 	#eg mon 23:00 or monday 23:00
);

=pod

=head2 EmailContentParser(\@emails)

\@emails is a reference to the emails array that contains the structure.

=cut

#parse data
sub EmailContentParser {
	my $emails = shift;
	my $events = shift;
	
	for (my $emailKey = 0; $emailKey < (scalar @$emails); $emailKey++)
	{
		my $email = $$emails[$emailKey];
		if ($email) 
		{
			#store fields from emails
			my $sentField = $email->{'sent'};
			my $contentField = $email->{'content'};
			my $timeTypeField = $email->{'timeType'};
			
			#create a shell
			$$events[$emailKey] =
			{
				"start" =>
				{
					"timezone" => "Australia/Melbourne",	#default to local
					$timeTypeField => "",
				},
				"end" =>
				{
					"timezone" => "Australia/Melbourne",	##default to local
					$timeTypeField => "",
				},
			};
			
			if ($emailKey == 1)
			{				
				print Dumper($events);
				
				#remove garbage from sent field
				$sentField =~ s/\s+|T+|-+|:+|.00Z+//g;
				
				#convert to a friendly format (inclusive of day)
				my $sentDate = Time::Piece->strptime($sentField, "%Y%m%d%H%M%S");
				
				my $eventStart = $sentDate;
				
				#iterate for seek
				foreach my $rsKey (keys %relativeSeek)
				{
					#if seek has found a potential range
					if ($contentField =~ m/$rsKey+/)
					{					
						#if the seek type is date	
						if ($relativeSeek{$rsKey} eq "date")
						{
							#iterate for all date patterns
							foreach my $datePattern (keys %datePatterns)
							{
								foreach my $day (keys %dayofweek)
								{
									(my $usePattern = $datePattern) =~ s/\$/$day/g;									
									my @seek = $contentField =~ m/$usePattern/ig;
									
									foreach my $seekResult (@seek)
									{
										if ($seekResult)
										{
											print $usePattern . "\n";
											print $rsKey . "->" . $seekResult . "\n";
											
											print "$eventStart\n";
																						
											if (%datePatterns->{$datePattern} eq "time12h")
											{
												#set sentdate to start of day
												#so that we can set the start/end of the event accordingly
												$eventStart -= ($eventStart->hour * 60 * 60);
												$eventStart -= ($eventStart->minute * 60);
												$eventStart -= $eventStart->second;
												
												#set event start
												$eventStart += ONE_DAY * ((%dayofweek->{$day} - $eventStart->day_of_week) % 7);
												
												$seekResult =~ s/(\d+)//g;
												$eventStart += ($1 * (60 * 60));
										
										#my $todayDate = strftime("%Y-%m-%dT%H:%M:%S.00Z", gmtime());
										
												EventAppend($events, $emailKey, "start", "datetime", Date::Format->strftime("%Y-%m-%dT%H:%M:%S.00Z", $eventStart));
												EventAppend($events, $emailKey, "end", "datetime", Date::Format->strftime("%Y-%m-%dT%H:%M:%S.00Z", ($eventStart + 3600)));
											}
										}
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
				
				
				
				EventPrinter($events);
				
				#print "[$emailKey]->$contentField\n";
				
				#https://timezonedb.com/api
				#http://api.timezonedb.com/?lat=53.7833&lng=-1.75&key=EHUCC69JBOJT&format=json
			}
		}
	}
}
#end parse data

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
		
			foreach my $key (keys %$startSection)
			{				
				print "$i->" . $key . " : " . %$startSection->{$key} . "\n";
			}
		
			print "-------------------\n";
			
			my $endSection = $event->{'end'};
			
			print "$i->END\n";
		
			foreach my $key (keys %$endSection)
			{				
				print "$i->" . $key . " : " . %$endSection->{$key} . "\n";
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
	}
	
	# if timeZone key specified, we change email type
	# to datetime as the event has time-specific
	if ($key eq "timeZone") {
		# if timeZone specified
		# modify shell
		$$emails[$$emailKey]->{'timeType'} = "datetime";
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