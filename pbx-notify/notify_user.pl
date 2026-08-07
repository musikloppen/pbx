#!/usr/bin/perl -w

use strict;
use warnings;
use utf8;

use Data::Dumper;
use POSIX qw( strftime );
use DBI;

use My::Db ();
use My::Utils qw( send_notify );

# Read notification templates directly from .env (with fallback defaults)
my $allow_message = $ENV{NOTIFICATION_ALLOW_MESSAGE}
	|| ('You now have access to open the gates.');

my $disallow_soon_message_template = $ENV{NOTIFICATION_DISALLOW_SOON_MESSAGE}
	|| 'Your access to the gate will expire DATE_TIME';

my $disallow_message = $ENV{NOTIFICATION_DISALLOW_MESSAGE}
	|| 'Your access to the gate has expired';

# Force immediate log flushing to STDOUT/STDERR
$| = 1;

# Graceful signal handling for Docker shutdown
my $RUNNING = 1;
$SIG{INT}  = sub { warn "[notify_user] Received SIGINT, shutting down cleanly...\n"; $RUNNING = 0; };
$SIG{TERM} = sub { warn "[notify_user] Received SIGTERM, shutting down cleanly...\n"; $RUNNING = 0; };

my $dbh;

warn "[notify_user] Starting daemon loop...\n";

# Initial Database Connection
while ($RUNNING && !$dbh) {
	$dbh = My::Db::connect();
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

				if (send_notify($d->{telephone}, $allow_message)) {
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
				my $msg = $disallow_soon_message_template;
				$msg =~ s/DATE_TIME/$end_string/g;

				if (send_notify($d->{telephone}, $msg)) {
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

				if (send_notify($d->{telephone}, $disallow_message)) {
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
