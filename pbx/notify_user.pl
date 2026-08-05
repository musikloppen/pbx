#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;

use Data::Dumper;
use POSIX qw( strftime );
use DBI;

use My::Utils qw( send_notify );

use constant ALLOW_MESSAGE          => 'You now have access to open the gates. The telephone number is: 32224307';
use constant DISALLOW_SOON_MESSAGE => 'Your access to the gate will expire DATE_TIME';
use constant DISALLOW_MESSAGE      => 'Your access to the gate has expired';

# Force immediate log flushing to STDOUT/STDERR
$| = 1;

# Graceful signal handling for Docker shutdown
my $RUNNING = 1;
$SIG{INT}  = sub { warn "[notify_user] Received SIGINT, shutting down cleanly...\n"; $RUNNING = 0; };
$SIG{TERM} = sub { warn "[notify_user] Received SIGTERM, shutting down cleanly...\n"; $RUNNING = 0; };

my $db_host = $ENV{DB_HOST} || 'pbx-db';
my $db_name = $ENV{MYSQL_DATABASE} || $ENV{DB_NAME} || 'pbx';
my $db_user = $ENV{MYSQL_USER}     || $ENV{DB_USER} || 'pbx';
my $db_pass = $ENV{MYSQL_PASSWORD} || $ENV{DB_PASS} || '';

my $dbi = "DBI:MariaDB:database=$db_name;host=$db_host;port=3306";
my $dbh;

warn "[notify_user] Starting daemon loop...\n";

# Initial Database Connection
while ($RUNNING && !$dbh) {
	$dbh = DBI->connect(
		$dbi,
		$db_user,
		$db_pass,
		{ 
			mariadb_auto_reconnect => 1, 
			mariadb_enable_utf8    => 1, 
			RaiseError             => 0, 
			PrintError             => 0 
		}
	);
	if (!$dbh) {
		warn sprintf("[notify_user ERROR] DB Connection failed: %s. Retrying in 2s...\n", $DBI::errstr || 'Unknown error');
		sleep 2;
	}
}

while ($RUNNING) {
	# -----------------------------------------------------------------
	# 1. Send allow notification to new users (notification_state = 0)
	# -----------------------------------------------------------------
	eval {
		my $sth = $dbh->prepare(qq[SELECT * FROM access WHERE `enabled` = 1 AND `notification_state` = 0]);
		if ($sth && $sth->execute()) {
			while (my $d = $sth->fetchrow_hashref) {
				last unless $RUNNING;
				warn sprintf("[notify_user] Trying to send allow notification to %s%s\n", 
					$d->{telephone}, ($d->{email} ? " or " . $d->{email} : ""));

				if (send_notify($d->{telephone}, ALLOW_MESSAGE)) {
					warn sprintf("[notify_user] Sent allow notification to %s\n", $d->{telephone});
					$dbh->do(qq[UPDATE access SET `notification_state` = 1 WHERE `id` = ?], undef, $d->{id});
					sleep 1;
				} else {
					warn sprintf("[notify_user WARN] Failed to send allow notification to %s\n", $d->{telephone});
				}
			}
		}
	};
	warn "[notify_user DB ERROR] Step 1 failed: $@\n" if $@;

	# -----------------------------------------------------------------
	# 2. Send disallow soon notification before expiration (notification_state = 1)
	# -----------------------------------------------------------------
	eval {
		my $sth = $dbh->prepare(qq[
			SELECT * FROM access 
			WHERE `enabled` = 1 
			  AND `end` > 0 
			  AND `notification_state` = 1 
			  AND NOW() > FROM_UNIXTIME(`end` - `notify_before_end`)
		]);
		if ($sth && $sth->execute()) {	
			while (my $d = $sth->fetchrow_hashref) {
				last unless $RUNNING;
				warn sprintf("[notify_user] Trying to send disallow soon notification to %s%s\n", 
					$d->{telephone}, ($d->{email} ? " or " . $d->{email} : ""));

				my $end_string = strftime("%d.%m.%Y at %H:%M:%S", localtime($d->{end}));
				my $disallow_soon_message = DISALLOW_SOON_MESSAGE;
				$disallow_soon_message =~ s/DATE_TIME/$end_string/;

				if (send_notify($d->{telephone}, $disallow_soon_message)) {
					warn sprintf("[notify_user] Sent disallow soon notification to %s\n", $d->{telephone});
					$dbh->do(qq[UPDATE access SET `notification_state` = 2 WHERE `id` = ?], undef, $d->{id});
					sleep 1;
				} else {
					warn sprintf("[notify_user WARN] Failed to send disallow soon notification to %s\n", $d->{telephone});
				}
			}
		}
	};
	warn "[notify_user DB ERROR] Step 2 failed: $@\n" if $@;

	# -----------------------------------------------------------------
	# 3. Send expired notification when account has expired (notification_state = 2)
	# -----------------------------------------------------------------
	eval {
		my $sth = $dbh->prepare(qq[
			SELECT * FROM access 
			WHERE `enabled` = 1 
			  AND `end` > 0 
			  AND `notification_state` = 2 
			  AND NOW() > FROM_UNIXTIME(`end`)
		]);
		if ($sth && $sth->execute()) {
			while (my $d = $sth->fetchrow_hashref) {
				last unless $RUNNING;
				warn sprintf("[notify_user] Trying to send expired notification to %s%s\n", 
					$d->{telephone}, ($d->{email} ? " or " . $d->{email} : ""));

				if (send_notify($d->{telephone}, DISALLOW_MESSAGE)) {
					warn sprintf("[notify_user] Sent expired notification to %s\n", $d->{telephone});
					$dbh->do(qq[UPDATE access SET `enabled` = 0, `notification_state` = 0 WHERE `id` = ?], undef, $d->{id});
					sleep 1;
				} else {
					warn sprintf("[notify_user WARN] Failed to send expired notification to %s\n", $d->{telephone});
				}
			}
		}
	};
	warn "[notify_user DB ERROR] Step 3 failed: $@\n" if $@;

	# Sleep interval split into 1-second chunks for fast SIGTERM response
	for (1 .. 10) {
		last unless $RUNNING;
		sleep 1;
	}
}

# Clean shutdown
if ($dbh) {
	$dbh->disconnect();
	warn "[notify_user] Database handle disconnected cleanly.\n";
}

warn "[notify_user] Process exited cleanly.\n";
exit 0;
