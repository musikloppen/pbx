#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use POSIX qw( strftime );
use Net::SMTP;
use DBI;

use constant ALLOW_MESSAGE => 'You now have access to open the gates. The telephone number is: 32224307';
use constant DISALLOW_SOON_MESSAGE => 'Your access to the gate will expire DATE_TIME';
use constant DISALLOW_MESSAGE => 'Your access to the gate has expired';

my $dbi = 'DBI:mysql:database=' . $ENV{MYSQL_DATABASE} . ';host=pbx-db;port=3306';
my $dbh;
my $sth;
my $d;

do {
	$dbh = DBI->connect($dbi, $ENV{MYSQL_USER}, $ENV{MYSQL_PASSWORD}, { mysql_auto_reconnect => 1, mysql_enable_utf8 => 1 }) || die $!;
	sleep 1;
} while (!$dbh);

while (1) {
	# send allow notification to new users
	$sth = $dbh->prepare(qq[SELECT * FROM access WHERE `enabled` AND `notification_state` = 0]);
	if ($sth->execute) {
		while ($d = $sth->fetchrow_hashref) {
			warn "Trying to send allow notification to " . $d->{telephone} . ($d->{email} ? " or " . $d->{email} . "\n" : "\n");
			if (send_notify($d->{telephone}, ALLOW_MESSAGE)) {
				warn "Sent notification to " . $d->{telephone} . ($d->{email} ? " or " . $d->{email} . "\n" : "\n");
				$dbh->do(qq[UPDATE access SET `notification_state` = 1 WHERE `id` = ] . $d->{id}) || warn $!;
				sleep 1;
			}
			else {
				warn "Failed to send notification to " . $d->{telephone} . ($d->{email} ? " or " . $d->{email} . "\n" : "\n");
			}
		}
	}
	else {
		 warn $!;
	}
	
	# send disallow notification to users before it expire
	$sth = $dbh->prepare(qq[SELECT * FROM access WHERE `enabled` \
		AND `end` \
		AND `notification_state` = 1 \
		AND NOW() > FROM_UNIXTIME(`end` - `notify_before_end`)]);
	if ($sth->execute) {	
		while ($d = $sth->fetchrow_hashref) {
			warn "Trying to send disallow soon notification to " . $d->{telephone} . ($d->{email} ? " or " . $d->{email} . "\n" : "\n");
			my $end_string = strftime("%d.%m.%Y at %H:%M:%S", localtime($d->{end}));
			my $disallow_soon_message = DISALLOW_SOON_MESSAGE;
			$disallow_soon_message =~ s/DATE_TIME/$end_string/;
			if (send_notify($d->{telephone}, $disallow_soon_message)) {
				warn "Sent notification to " . $d->{telephone} . ($d->{email} ? " or " . $d->{email} . "\n" : "\n");
				$dbh->do(qq[UPDATE access SET `notification_state` = 2 WHERE `id` = ] . $d->{id}) || warn $!;
				sleep 1;
			}
			else {
				warn "Failed to send notification to " . $d->{telephone} . ($d->{email} ? " or " . $d->{email} . "\n" : "\n");
			}
		}
	}
	else {
		 warn $!;
	}
	
	# send disallow notification to users when it has expired
	$sth = $dbh->prepare(qq[SELECT * FROM access WHERE `enabled` \
		AND `end` \
		AND `notification_state` = 2 \
		AND NOW() > FROM_UNIXTIME(`end`)]);
	if ($sth->execute) {
		while ($d = $sth->fetchrow_hashref) {
			warn "Trying to send expired notification to " . $d->{telephone} . ($d->{email} ? " or " . $d->{email} . "\n" : "\n");
			if (send_notify($d->{telephone}, DISALLOW_MESSAGE)) {
				warn "Sent notification to " . $d->{telephone} . ($d->{email} ? " or " . $d->{email} . "\n" : "\n");
				$dbh->do(qq[UPDATE access SET `enabled` = 0, `notification_state` = 0 WHERE `id` = ] . $d->{id}) || warn $!;
				sleep 1;
			}
			else {
				warn "Failed to send notification to " . $d->{telephone} . ($d->{email} ? " or " . $d->{email} . "\n" : "\n");
			}
		}
	}
	else {
		 warn $!;
	}
	
	sleep 10;
}

sub send_notify {
	my ($telephone, $message) = @_;
	my $smtp;
	
	eval {
		$smtp = Net::SMTP->new('postfix');
		$smtp->mail('meterlogger');
		$smtp->to('45' . $d->{telephone} . '@meterlogger');
		$smtp->data();
		$smtp->datasend("$message");
		$smtp->dataend();
		$smtp->quit;
	};
	if ($@) {
		if (defined($smtp)) {
			warn "SMTP error: ", $smtp->message();		
		}
		else {
			warn $@;
		}
		return 0;
	}
	else {
		return 1;
	}
}

1;
