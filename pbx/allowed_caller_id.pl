#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use DBI;

use My::Db qw( connect );

# Force immediate log flushing to STDOUT/STDERR
$| = 1;

my $caller_id = $ARGV[0] // '';

# Strip all non-digit characters (e.g. +, spaces, dashes)
$caller_id =~ s/\D//g;

# Basic sanity check: must contain at least 8 digits
if (length($caller_id) < 8) {
	exit 1;
}

my $dbh = connect() or die "[allowed_caller_id FATAL] Connection failed: " . ($DBI::errstr || 'Unknown error');

# Log the initial incoming call attempt
eval {
	my $sth_log = $dbh->prepare(qq[
		INSERT INTO log (`caller_id`, `event`, `unix_time`) 
		VALUES (?, 'called', UNIX_TIMESTAMP())
	]);
	$sth_log->execute($caller_id);
};

# Query access table matching clean database telephone ending with caller_id
my $like_pattern = '%' . $caller_id;

my $sth_access = $dbh->prepare(qq[
	SELECT COUNT(*) FROM `access` 
	WHERE `enabled` = 1 
	  AND (
	    (FROM_UNIXTIME(`start`) <= NOW() AND NOW() <= FROM_UNIXTIME(`end`)) 
	    OR ((`start` IS NULL OR `start` = 0) AND NOW() <= FROM_UNIXTIME(`end`)) 
	    OR ((`start` IS NULL OR `start` = 0) AND (`end` IS NULL OR `end` = 0))
	  ) 
	  AND REGEXP_REPLACE(`telephone`, '[^0-9]', '') LIKE ?
]);

$sth_access->execute($like_pattern);
my ($allowed_count) = $sth_access->fetchrow_array();

if ($allowed_count && $allowed_count > 0) {
	eval {
		my $sth_log = $dbh->prepare(qq[
			INSERT INTO log (`caller_id`, `event`, `unix_time`) 
			VALUES (?, 'allowed', UNIX_TIMESTAMP())
		]);
		$sth_log->execute($caller_id);
	};
	$dbh->disconnect();
	exit 0;
} else {
	eval {
		my $sth_log = $dbh->prepare(qq[
			INSERT INTO log (`caller_id`, `event`, `unix_time`) 
			VALUES (?, 'not allowed', UNIX_TIMESTAMP())
		]);
		$sth_log->execute($caller_id);
	};
	$dbh->disconnect();
	exit 1;
}
