#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use DBI;

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

# Read connection parameters from environment (sourced via /etc/cron_env in crontab)
my $db_host = $ENV{DB_HOST} || 'pbx-db';
my $db_port = $ENV{DB_PORT} || 3306;
my $db_name = $ENV{DB_NAME} || 'pbx';
my $db_user = $ENV{DB_USER} || 'pbx';
my $db_pass = $ENV{DB_PASS} || '';

my $dsn = "DBI:mysql:database=$db_name;host=$db_host;port=$db_port";
my $dbh = DBI->connect(
	$dsn,
	$db_user,
	$db_pass,
	{
		RaiseError           => 0,
		PrintError           => 0,
		AutoCommit           => 1,
		mysql_enable_utf8    => 1,
		mysql_auto_reconnect => 1,
	}
);

unless ($dbh) {
	log_die("Cannot connect to database '$dsn': " . ($DBI::errstr || 'Unknown error'));
}

log_info("Connected to MariaDB ($db_name at $db_host:$db_port)");

# -------------------------------------------------------------------------
# 1. Clean Stale sms_auth Entries
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

# -------------------------------------------------------------------------
# 2. Delete Expired Guest Access Entries
# -------------------------------------------------------------------------
log_info("Cleaning expired guest access entries...");

my $rows_deleted = $dbh->do(qq[
	DELETE FROM access 
	WHERE `admin` = 'guest' 
	  AND `expire_at` IS NOT NULL 
	  AND `expire_at` < NOW()
]);

if (defined $rows_deleted && $rows_deleted > 0) {
	log_info("Deleted $rows_deleted expired guest access entry/entries.");
} else {
	log_info("No expired guest access entries found.");
}

$dbh->disconnect();
log_info("Cleanup task completed successfully.");

1;
