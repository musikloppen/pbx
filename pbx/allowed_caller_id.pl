#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use DBI;

my $caller_id = $ARGV[0] // '';

# Strip all non-digit characters (e.g. +, spaces, dashes)
$caller_id =~ s/\D//g;

# Basic sanity check: must contain at least 8 digits
if (length($caller_id) < 8) {
	exit 1;
}

my $dbi = 'DBI:MariaDB:database=$MYSQL_DATABASE;host=pbx-db;port=3306';

my $dbh = DBI->connect($dbi, '$MYSQL_USER', '$MYSQL_PASSWORD', { mysql_auto_reconnect => 1, mysql_enable_utf8 => 1 }) || die $!;

my $quoted_caller_id = $dbh->quote($caller_id);
my $like_pattern     = $dbh->quote('%' . $caller_id);

# Log the initial incoming call attempt
$dbh->do(qq[INSERT INTO log (`caller_id`, `event`, `unix_time`) VALUES ($quoted_caller_id, 'called', UNIX_TIMESTAMP())]) || die $!;

# Query access table matching clean database telephone ending with caller_id
my $sth = $dbh->prepare(qq[SELECT COUNT(*) FROM `access` WHERE `enabled` = 1 \
	AND ((FROM_UNIXTIME(`start`) <= NOW() AND NOW() <= FROM_UNIXTIME(`end`)) \
		OR ((`start` IS NULL OR `start` = 0) AND NOW() <= FROM_UNIXTIME(`end`)) \
		OR ((`start` IS NULL OR `start` = 0) AND (`end` IS NULL OR `end` = 0))) \
	AND REGEXP_REPLACE(`telephone`, '[^0-9]', '') LIKE $like_pattern]);

$sth->execute || die $!;

if ($sth->fetchrow_array > 0) {
	$dbh->do(qq[INSERT INTO log (`caller_id`, `event`, `unix_time`) VALUES ($quoted_caller_id, 'allowed', UNIX_TIMESTAMP())]) || die $!;
	exit 0;
}
else {
	$dbh->do(qq[INSERT INTO log (`caller_id`, `event`, `unix_time`) VALUES ($quoted_caller_id, 'not allowed', UNIX_TIMESTAMP())]) || die $!;
	exit 1;
}
