#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use DBI;

use My::Db qw( connect );

# Force immediate log flushing to STDOUT/STDERR (vital for Docker/Cron)
$| = 1;

sub log_info {
	my $msg = shift;
	print STDOUT "[CRON INFO] $msg\n";
}

sub log_warn {
	my $msg = shift;
	warn "[CRON WARN] $msg\n";
}

sub log_die {
	my $msg = shift;
	die "[CRON FATAL] $msg\n";
}

log_info("Starting DB cleanup task...");

my $dbh = connect();

unless ($dbh) {
	log_die("Cannot connect to database: " . ($DBI::errstr || 'Unknown error'));
}

log_info("Connected to MariaDB via My::Db");

# -------------------------------------------------------------------------
# Clean Stale sms_auth Entries
# -------------------------------------------------------------------------
log_info("Cleaning sms_auth table...");

my $del_new = $dbh->do(qq[
	DELETE FROM sms_auth 
	WHERE `auth_state` = 'new' 
	  AND FROM_UNIXTIME(`unix_time`) < NOW() - INTERVAL 1 HOUR
]);
if (defined $del_new && $del_new > 0) {
	log_info("Deleted $del_new stale 'new' sms_auth entry/entries.");
}

my $del_login = $dbh->do(qq[
	DELETE FROM sms_auth 
	WHERE `auth_state` = 'login' 
	  AND FROM_UNIXTIME(`unix_time`) < NOW() - INTERVAL 1 DAY
]);
if (defined $del_login && $del_login > 0) {
	log_info("Deleted $del_login stale 'login' sms_auth entry/entries.");
}

my $del_sent = $dbh->do(qq[
	DELETE FROM sms_auth 
	WHERE `auth_state` = 'sms_code_sent' 
	  AND FROM_UNIXTIME(`unix_time`) < NOW() - INTERVAL 1 DAY
]);
if (defined $del_sent && $del_sent > 0) {
	log_info("Deleted $del_sent stale 'sms_code_sent' sms_auth entry/entries.");
}

my $total_sms_deleted = ($del_new || 0) + ($del_login || 0) + ($del_sent || 0);
if ($total_sms_deleted == 0) {
	log_info("No stale sms_auth entries found.");
}

$dbh->disconnect();
log_info("Cleanup task completed successfully.");

1;
