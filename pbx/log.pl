#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use DBI;

use My::Db qw( connect );
use My::Number::Phone;

# Force immediate log flushing to STDOUT/STDERR for Docker logs
$| = 1;

my $raw_caller_id = $ARGV[0];
my $event         = $ARGV[1];

# Normalize phone number if present
my $normalized_caller_id = $raw_caller_id;
if ($raw_caller_id) {
	my $phone_obj = My::Number::Phone->new($raw_caller_id);
	if ($phone_obj && $phone_obj->is_valid) {
		$normalized_caller_id = $phone_obj->compact; # or ->international
	}
}

my $dbh = connect( PrintError => 1 ) or die "[log.pl FATAL] Connection failed: " . ($DBI::errstr || 'Unknown error');

my $sth = $dbh->prepare(qq[
	INSERT INTO log (`caller_id`, `event`, `unix_time`) 
	VALUES (?, ?, UNIX_TIMESTAMP())
]);

$sth->execute($normalized_caller_id, $event) or warn "[log.pl WARN] Execution failed: " . ($DBI::errstr || $!);

$dbh->disconnect();

1;
