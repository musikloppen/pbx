#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use My::Number::Phone;

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

my $db_host = $ENV{DB_HOST} || 'pbx-db';
my $db_name = $ENV{MYSQL_DATABASE} || 'pbx';
my $db_user = $ENV{MYSQL_USER} || 'pbx';
my $db_pass = $ENV{MYSQL_PASSWORD} || '';

my $dbh = DBI->connect(
	"DBI:MariaDB:database=$db_name;host=$db_host;port=3306",
	$db_user,
	$db_pass,
	{ RaiseError => 0, PrintError => 1, mysql_auto_reconnect => 1, mysql_enable_utf8 => 1 }
) or die $!;

my $sth = $dbh->prepare(qq[
	INSERT INTO log (`caller_id`, `event`, `unix_time`) 
	VALUES (?, ?, UNIX_TIMESTAMP())
]);

$sth->execute($normalized_caller_id, $event) or warn $!;

1;
