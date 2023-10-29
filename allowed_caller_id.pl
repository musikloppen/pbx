#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use DBI;

my $caller_id = $ARGV[0];

my $dbi = 'DBI:mysql:database=$MYSQL_DATABASE;host=db;port=3306';

my $dbh = DBI->connect($dbi, $MYSQL_USER, $MYSQL_PASSWORD, { mysql_auto_reconnect => 1, mysql_enable_utf8 => 1 }) || die $!;

# check if caller id is present and longer than 8 numbers
if (length($caller_id) < 8) {
	die;
}

my $quoted_caller_id = $dbh->quote($caller_id);

# check if caller id is in db
my $sth = $dbh->prepare(qq[SELECT COUNT(*) FROM `access` WHERE `enabled` \
	AND ((FROM_UNIXTIME(`start`) <= NOW() AND NOW() <= FROM_UNIXTIME(`end`)) \
		OR ((`start` IS NULL OR `start` = 0) AND NOW() <= FROM_UNIXTIME(`end`)) \
		OR ((`start` IS NULL OR `start` = 0) AND (`end` IS NULL OR `end` = 0))) \
		AND `telephone` = ] . $quoted_caller_id);
$sth->execute || die $!;

if ($sth->fetchrow_array > 0) {
	exit 0;
}
else {
	exit 1;
}
