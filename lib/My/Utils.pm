package My::Utils;

use strict;
use warnings;
use utf8;

use Exporter 'import';
our @EXPORT_OK = qw( send_notify );

use Net::SMTP;
use Email::MIME;
use Encode qw( decode is_utf8 );
use My::Number::Phone;

# -------------------------------------------------------------------------
# Shared Helper: Send SMS via Configured SMTP Server
# -------------------------------------------------------------------------
sub send_notify {
	my ($sms_number, $message) = @_;
	return 0 unless $sms_number && $message;

	eval {
		# Validate and normalize phone number
		my $phone_obj = My::Number::Phone->new($sms_number);
		unless ($phone_obj && $phone_obj->is_valid) {
			warn sprintf("[My::Utils WARN] Cannot send SMS: Invalid phone number format '%s'\n", $sms_number);
			return 0;
		}

		# Strictly enforce international format (e.g., 004512345678)
		$sms_number = $phone_obj->international;

		# Check DEBUG mode
		if ($ENV{DEBUG}) {
			warn sprintf("[My::Utils DEBUG DRY-RUN] Skipping actual SMTP dispatch. SMS to %s: \"%s\"\n", $sms_number, $message);
			return 1;
		}

		my $smtp_host = $ENV{SMTP_HOST} || 'postfix';
		my $smtp_port = $ENV{SMTP_PORT} || 25;

		unless (is_utf8($message)) {
			$message = decode('UTF-8', $message);
		}

		my $email = Email::MIME->create(
			header_str => [
				From    => 'meterlogger@meterlogger',
				To      => $sms_number . '@meterlogger',
				Subject => $message,
			],
			attributes => {
				encoding     => 'quoted-printable',
				charset      => 'UTF-8',
				content_type => 'text/plain',
			},
			body => '',
		);

		my %smtp_opts = (
			Port    => $smtp_port,
			Timeout => 10,
		);
		if ($smtp_port == 465) {
			$smtp_opts{SSL} = 1;
		}

		my $smtp = Net::SMTP->new($smtp_host, %smtp_opts);
		unless ($smtp) {
			warn sprintf("[My::Utils WARN] Cannot connect to SMTP server at %s:%s\n", $smtp_host, $smtp_port);
			return 0;
		}

		my $smtp_user = $ENV{SMTP_USER};
		my $smtp_pass = $ENV{SMTP_PASSWORD};
		if ($smtp_user && $smtp_pass) {
			unless ($smtp->auth($smtp_user, $smtp_pass)) {
				warn "[My::Utils WARN] SMTP AUTH failed: " . $smtp->message() . "\n";
				$smtp->quit();
				return 0;
			}
		}

		unless ($smtp->mail('meterlogger@meterlogger')) {
			warn "[My::Utils WARN] SMTP MAIL FROM failed: " . $smtp->message() . "\n";
			$smtp->quit();
			return 0;
		}

		unless ($smtp->to("$sms_number\@meterlogger")) {
			warn "[My::Utils WARN] SMTP RCPT TO failed: " . $smtp->message() . "\n";
			$smtp->quit();
			return 0;
		}

		unless ($smtp->data()) {
			warn "[My::Utils WARN] SMTP DATA failed: " . $smtp->message() . "\n";
			$smtp->quit();
			return 0;
		}

		unless ($smtp->datasend($email->as_string)) {
			warn "[My::Utils WARN] SMTP DATASEND failed: " . $smtp->message() . "\n";
			$smtp->quit();
			return 0;
		}

		unless ($smtp->dataend()) {
			warn "[My::Utils WARN] SMTP DATAEND failed: " . $smtp->message() . "\n";
			$smtp->quit();
			return 0;
		}

		$smtp->quit();
		warn sprintf("[My::Utils INFO] SMS sent to %s via %s\n", $sms_number, $smtp_host);
		return 1;
	};

	if ($@) {
		warn sprintf("[My::Utils WARN] Failed to send SMS to %s: %s\n", $sms_number, $@);
		return 0;
	}

	return 1;
}

1;
