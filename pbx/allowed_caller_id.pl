#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use DBI;
use My::Number::Phone;

my $caller_id = $ARGV[0];

# Normalize caller_id using My::Number::Phone
my $phone_obj = My::Number::Phone->new($caller_id);

unless ($phone_obj && $phone_obj->is_valid) {
	# Invalid phone format
	exit 1;
}

my $normalized_caller_id = $phone_obj->compact;

my $dbi = 'DBI:mysql:database=$MYSQL_DATABASE;host=pbx-db;port=3306';

my $dbh = DBI->connect($dbi, '$MYSQL_USER', '$MYSQL_PASSWORD', { mysql_auto_reconnect => 1, mysql_enable_utf8 => 1 }) || die $!;

my $quoted_caller_id = $dbh->quote($normalized_caller_id);

$dbh->do(qq[INSERT INTO log (`caller_id`, `event`, `unix_time`) VALUES ($quoted_caller_id, 'called', UNIX_TIMESTAMP())]) || die $!;

# check if caller id is present and longer than 8 numbers
if (length($normalized_caller_id) < 8) {
	exit 1;
}

# check if caller id is in db
my $sth = $dbh->prepare(qq[SELECT COUNT(*) FROM `access` WHERE `enabled` \
	AND ((FROM_UNIXTIME(`start`) <= NOW() AND NOW() <= FROM_UNIXTIME(`end`)) \
		OR ((`start` IS NULL OR `start` = 0) AND NOW() <= FROM_UNIXTIME(`end`)) \
		OR ((`start` IS NULL OR `start` = 0) AND (`end` IS NULL OR `end` = 0))) \
		AND `telephone` = ] . $quoted_caller_id);
$sth->execute || die $!;

if ($sth->fetchrow_array > 0) {
	$dbh->do(qq[INSERT INTO log (`caller_id`, `event`, `unix_time`) VALUES ($quoted_caller_id, 'allowed', UNIX_TIMESTAMP())]) || die $!;
	exit 0;
}
else {
	$dbh->do(qq[INSERT INTO log (`caller_id`, `event`, `unix_time`) VALUES ($quoted_caller_id, 'not allowed', UNIX_TIMESTAMP())]) || die $!;
	exit 1;
}
