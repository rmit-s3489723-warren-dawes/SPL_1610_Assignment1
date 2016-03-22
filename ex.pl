#!/usr/bin/env perl
use strict;
use warnings;

open my $openfile, "emails.json" or die "Error opening file: $!\n";

my @contents = <$openfile>;

close $openfile;

foreach my $line (@contents) {
	print "Line -> $line";
}