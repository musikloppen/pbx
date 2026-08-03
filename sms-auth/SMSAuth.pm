package SMSAuth;

use parent 'Plack::Middleware';

use strict;
use warnings;
use utf8;

use CGI::Simple::Cookie;
use Math::Random::Secure qw(rand);
use DBI;
use Plack::Request;
use Plack::Response;
use Plack::Util::Accessor qw(
	logout_path
	logged_out_path
	public_access
	snooze_page
	snooze_api
	login_path
	sms_code_path
	default_path
	user_admin_access
);

use Net::SMTP;
use Email::MIME;
use Encode qw(decode is_utf8);

use My::Number::Phone;

# -------------------------------------------------------------------------
# Embedded Helper: Send SMS via Configured SMTP Server
# -------------------------------------------------------------------------
sub send_notification {
	my ($req, $sms_number, $message) = @_;
	return 0 unless $sms_number && $message;

	eval {
		# Validate and normalize phone number
		my $phone_obj = My::Number::Phone->new($sms_number);
		unless ($phone_obj && $phone_obj->is_valid) {
			warn "[SMSAuth WARN] Cannot send SMS: Invalid phone number format '$sms_number'\n";
			return 0;
		}

		# Strictly enforce 00 prefix formatting (e.g., 004512345678)
		$sms_number = $phone_obj->international;

		# Check DEBUG mode
		my $debug = $ENV{DEBUG};
		if ($debug) {
			warn "[SMSAuth DEBUG DRY-RUN] Skipping actual SMTP dispatch. SMS to $sms_number: \"$message\"\n";
			return 1;
		}

		my $smtp_host = $ENV{SMTP_HOST};
		my $smtp_port = $ENV{SMTP_PORT} || 25;

		unless ($smtp_host) {
			warn "[SMSAuth WARN] Mandatory environment variable missing: SMTP_HOST\n";
			return 0;
		}

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
			warn "[SMSAuth WARN] Cannot connect to SMTP server at $smtp_host:$smtp_port\n";
			return 0;
		}

		my $smtp_user = $ENV{SMTP_USER};
		my $smtp_pass = $ENV{SMTP_PASSWORD};
		if ($smtp_user && $smtp_pass) {
			unless ($smtp->auth($smtp_user, $smtp_pass)) {
				warn "[SMSAuth WARN] SMTP AUTH failed: " . $smtp->message() . "\n";
				$smtp->quit();
				return 0;
			}
		}

		unless ($smtp->mail('meterlogger@meterlogger')) {
			warn "[SMSAuth WARN] SMTP MAIL FROM failed: " . $smtp->message() . "\n";
			$smtp->quit();
			return 0;
		}

		unless ($smtp->to("$sms_number\@meterlogger")) {
			warn "[SMSAuth WARN] SMTP RCPT TO failed: " . $smtp->message() . "\n";
			$smtp->quit();
			return 0;
		}

		unless ($smtp->data()) {
			warn "[SMSAuth WARN] SMTP DATA failed: " . $smtp->message() . "\n";
			$smtp->quit();
			return 0;
		}

		unless ($smtp->datasend($email->as_string)) {
			warn "[SMSAuth WARN] SMTP DATASEND failed: " . $smtp->message() . "\n";
			$smtp->quit();
			return 0;
		}

		unless ($smtp->dataend()) {
			warn "[SMSAuth WARN] SMTP DATAEND failed: " . $smtp->message() . "\n";
			$smtp->quit();
			return 0;
		}

		$smtp->quit();
		warn "[SMSAuth INFO] SMS sent to $sms_number via $smtp_host\n";
		return 1;
	};

	if ($@) {
		warn "[SMSAuth WARN] Failed to send SMS to $sms_number: $@\n";
		return 0;
	}

	return 1;
}

# Internal DB connector reading from Docker container environment
sub _get_dbh {
	my $db_host = $ENV{DB_HOST} || 'pbx-db';
	my $db_name = $ENV{DB_NAME} || 'pbx';
	my $db_user = $ENV{DB_USER} || 'pbx';
	my $db_pass = $ENV{DB_PASS} || '';

	warn sprintf("[SMSAuth DB] Connecting to DBI:mysql:database=%s;host=%s as user %s...\n", $db_name, $db_host, $db_user);

	my $dbh = DBI->connect(
		"DBI:mysql:database=$db_name;host=$db_host",
		$db_user,
		$db_pass,
		{ RaiseError => 0, PrintError => 0, AutoCommit => 1, mysql_enable_utf8 => 1 }
	);

	if (!$dbh) {
		warn sprintf("[SMSAuth DB ERROR] Connection failed: %s\n", $DBI::errstr || 'Unknown error');
	} else {
		warn sprintf("[SMSAuth DB] Connected successfully (Handle: %s)\n", $dbh);
	}

	return $dbh;
}

sub prepare_app {
	my $self = shift;
	$self->logout_path($self->logout_path || 'logout');
	$self->logged_out_path($self->logged_out_path || '/logged_out.html');
	$self->login_path($self->login_path || '/private/login.html');
	$self->sms_code_path($self->sms_code_path || '/private/sms_code.html');
	$self->default_path($self->default_path || '/');
	$self->public_access([ split(/,\s*/, $self->public_access || '') ]);
	$self->user_admin_access([ split(/,\s*/, $self->user_admin_access || '') ]);

	warn "[SMSAuth INIT] Prepared app middleware settings\n";
}

sub call {
	my ($self, $env) = @_;
	my $req = Plack::Request->new($env);

	my $orig_uri = $req->request_uri;
	my $path     = $req->path_info;

	warn sprintf("[SMSAuth CALL] Method: %s | Request URI: %s | Path Info: %s\n", $req->method, $orig_uri, $path);

	# Bypass configured public paths
	foreach my $pub (@{ $self->public_access }) {
		if ($path eq $pub) {
			warn sprintf("[SMSAuth BYPASS] Public access path matched: %s\n", $pub);
			return $self->app->($env);
		}
	}

	if ($path eq $self->logged_out_path) {
		warn sprintf("[SMSAuth BYPASS] Logged out path matched: %s\n", $self->logged_out_path);
		return $self->app->($env);
	}

	my $dbh = _get_dbh();
	unless ($dbh) {
		warn "[SMSAuth ERROR] Unable to obtain DB handle. Returning HTTP 503\n";
		my $res = Plack::Response->new(503);
		$res->headers({ 'Retry-After' => '60' });
		$res->body("Service Unavailable: Database Connection Failed");
		return $res->finalize;
	}

	if (index($orig_uri, $self->logout_path) >= 0) {
		warn sprintf("[SMSAuth ROUTE] Routing to logout_handler (logout_path: %s)\n", $self->logout_path);
		return $self->logout_handler($req, $dbh);
	}

	warn "[SMSAuth ROUTE] Routing to login_handler\n";
	return $self->login_handler($req, $dbh, $env);
}

sub login_handler {
	my ($self, $req, $dbh, $env) = @_;

	my $cookies = $req->cookies;
	my $passed_cookie_token = $cookies->{'auth_token'};

	warn sprintf("[SMSAuth COOKIE] Incoming auth_token: %s\n", $passed_cookie_token || '<NONE>');

	my $cookie_token;
	my $set_cookie_header;

	if ($passed_cookie_token) {
		$cookie_token = $passed_cookie_token;
	} else {
		$cookie_token = unpack('H*', join('', map { chr(int Math::Random::Secure::rand(256)) } 1 .. 16));
		warn sprintf("[SMSAuth COOKIE] Generated new auth_token: %s\n", $cookie_token);
		$set_cookie_header = CGI::Simple::Cookie->new(
			-name     => 'auth_token',
			-value    => $cookie_token,
			-expires  => '+1y',
			-httponly => 1,
			-secure   => 0
		)->as_string;
	}

	my $quoted_token = $dbh->quote($passed_cookie_token || $cookie_token);
	
	my $sql_session_check = qq[SELECT `auth_state` FROM sms_auth WHERE cookie_token LIKE $quoted_token LIMIT 1];
	warn sprintf("[SMSAuth DB QUERY] Executing: %s\n", $sql_session_check);
	my $sth = $dbh->prepare($sql_session_check);
	$sth->execute;

	if (my $d = $sth->fetchrow_hashref) {
		my $state = lc($d->{auth_state} || '');
		warn sprintf("[SMSAuth STATE] Found existing session token. Current auth_state: '%s'\n", $state);

		# 1. Fully Authenticated Access
		if ($state eq 'sms_code_verified') {
			warn sprintf("[SMSAuth STATE sms_code_verified] User authenticated. Access granted to: %s\n", $req->path_info);
			my $sql_touch_time = qq[UPDATE sms_auth SET unix_time = ] . time() . qq[ WHERE cookie_token = $quoted_token];
			$dbh->do($sql_touch_time);

			return $self->app->($env);
		}

		# 2. Allow access to login form and SMS code page during login flow
		if ($req->path_info eq $self->login_path) {
			if ($state eq 'new') {
				my $sql_update_new = qq[UPDATE sms_auth SET auth_state = 'login', unix_time = ] . time() . qq[ WHERE cookie_token = $quoted_token];
				warn sprintf("[SMSAuth DB EXEC] %s\n", $sql_update_new);
				$dbh->do($sql_update_new);
			}

			# Submit phone number form
			if ($req->method eq 'POST') {
				my $raw_phone = $req->param('id');
				warn sprintf("[SMSAuth STATE login] Submitted phone parameter 'id': %s\n", $raw_phone || '<NONE>');

				my $phone_obj = My::Number::Phone->new($raw_phone);
				unless ($phone_obj && $phone_obj->is_valid) {
					warn sprintf("[SMSAuth STATE login] Invalid phone number submitted: '%s'\n", $raw_phone || '<NONE>');
					$env->{PATH_INFO} = $self->login_path;
					return $self->app->($env);
				}

				my $normalized_phone = $phone_obj->compact;
				my $user_is_in_db = 0;

				if ($normalized_phone) {
					my $quoted_phone = $dbh->quote($normalized_phone);
					my $sql_access = qq[SELECT `telephone` FROM access WHERE `enabled` = 1 AND `telephone` = $quoted_phone LIMIT 1];
					warn sprintf("[SMSAuth DB QUERY] Executing: %s\n", $sql_access);
					my $s2 = $dbh->prepare($sql_access);
					$s2->execute;
					$user_is_in_db = $s2->rows;
					warn sprintf("[SMSAuth DB RESULT] Access table match count: %d\n", $user_is_in_db);
				}

				if ($user_is_in_db) {
					my $sms_code = join('', map { int(Math::Random::Secure::rand(10)) } 1 .. 6);
					warn sprintf("[SMSAuth STATE login] Phone verified! Generated SMS Code: %s\n", $sms_code);

					my $sql_update_login = qq[UPDATE sms_auth SET `auth_state` = 'sms_code_sent', `sms_code` = ] . $dbh->quote($sms_code) . qq[, `phone` = ] . $dbh->quote($normalized_phone) . qq[, unix_time = ] . time() . qq[ WHERE cookie_token = $quoted_token];
					warn sprintf("[SMSAuth DB EXEC] %s\n", $sql_update_login);
					$dbh->do($sql_update_login);

					# Send the SMS code notification via embedded send_notification
					my $sms_template = $ENV{'NOTIFICATION_SMS_CODE_MESSAGE'} || 'SMS Code: {sms_code}';
					my $sms_message  = $sms_template;
					$sms_message =~ s/\{sms_code\}/$sms_code/g;

					send_notification($req, $normalized_phone, $sms_message);

					my $session_cookie = CGI::Simple::Cookie->new(
						-name     => 'auth_token',
						-value    => $cookie_token,
						-httponly => 1,
						-secure   => 0
					)->as_string;

					warn sprintf("[SMSAuth STATE login] Redirecting to sms_code_path (%s)\n", $self->sms_code_path);
					return $self->redirect_with_cookie($self->sms_code_path, $session_cookie);
				} else {
					warn sprintf("[SMSAuth STATE login] Normalized phone '%s' NOT matched in access table. Re-rendering login form (%s)\n", $normalized_phone || '<NONE>', $self->login_path);
					$env->{PATH_INFO} = $self->login_path;
					return $self->app->($env);
				}
			}

			# GET request to render login HTML page
			return $self->app->($env);
		}

		if ($req->path_info eq $self->sms_code_path) {
			if ($state eq 'sms_code_sent' && $req->method eq 'POST') {
				my $sms_code       = $req->param('sms_code');
				my $stay_logged_in = $req->param('stay_logged_in');

				warn sprintf("[SMSAuth STATE sms_code_sent] Submitted sms_code: '%s' | stay_logged_in: '%s'\n", $sms_code || '<NONE>', $stay_logged_in || 'false');

				my $cookie_opts = { -name => 'auth_token', -value => ($passed_cookie_token || ''), -httponly => 1, -secure => 0 };
				$cookie_opts->{-expires} = '+1y' if $stay_logged_in;
				my $auth_cookie = CGI::Simple::Cookie->new(%$cookie_opts)->as_string;

				my $sql_verify_code = qq[SELECT `sms_code`, `orig_uri` FROM sms_auth WHERE `cookie_token` LIKE $quoted_token AND `sms_code` LIKE ] . $dbh->quote($sms_code) . qq[ LIMIT 1];
				warn sprintf("[SMSAuth DB QUERY] Executing: %s\n", $sql_verify_code);
				my $c_sth = $dbh->prepare($sql_verify_code);
				$c_sth->execute;

				if (my $cd = $c_sth->fetchrow_hashref) {
					warn sprintf("[SMSAuth STATE sms_code_sent] SMS code MATCHED! Target orig_uri: %s\n", $cd->{orig_uri} || $self->default_path);

					my $sql_update_verified = qq[UPDATE sms_auth SET `auth_state` = 'sms_code_verified', `session` = ] . ($stay_logged_in ? 0 : 1) . qq[, unix_time = ] . time() . qq[ WHERE cookie_token = $quoted_token];
					warn sprintf("[SMSAuth DB EXEC] %s\n", $sql_update_verified);
					$dbh->do($sql_update_verified);

					$self->log_admin_event($dbh, $req, 'login', $quoted_token);
					return $self->redirect_with_cookie($cd->{orig_uri}, $auth_cookie);
				} else {
					warn sprintf("[SMSAuth STATE sms_code_sent] Invalid SMS code. Internal forward to sms_code_path (%s)\n", $self->sms_code_path);
					$env->{PATH_INFO} = $self->sms_code_path;
					return $self->app->($env);
				}
			}

			# GET request to render SMS code form
			return $self->app->($env);
		}

		# 3. Unauthenticated access to protected path -> Redirect to login page
		warn sprintf("[SMSAuth STATE %s] Unauthenticated attempt to access '%s'. Redirecting to login_path (%s)\n", $state, $req->path_info, $self->login_path);
		return $self->redirect_with_cookie($self->login_path, $set_cookie_header);
	}
	else {
		# No session record in DB -> Create initial session and redirect to login
		warn sprintf("[SMSAuth STATE new] No session record found for cookie token '%s'. Creating session\n", $cookie_token);

		my $remote_host = $req->header('X-Real-IP') || $req->header('X-Forwarded-For') || $req->address;
		my $user_agent  = $req->user_agent;

		my $target_uri = $req->request_uri;
		if ($target_uri =~ /${\$self->login_path}|${\$self->logout_path}|${\$self->logged_out_path}|${\$self->sms_code_path}/) {
			$target_uri = $self->default_path;
		}

		warn sprintf("[SMSAuth STATE new] Storing new session with orig_uri: %s\n", $target_uri);

		my $sql_insert_session = qq[
			INSERT INTO sms_auth (cookie_token, auth_state, orig_uri, remote_host, user_agent, unix_time)
			VALUES (] . $dbh->quote($cookie_token) . qq[, 'new', ] . $dbh->quote($target_uri) . qq[, ] . $dbh->quote($remote_host) . qq[, ] . $dbh->quote($user_agent) . qq[, ] . time() . qq[)
		];
		warn sprintf("[SMSAuth DB EXEC] %s\n", $sql_insert_session);
		$dbh->do($sql_insert_session);

		return $self->redirect_with_cookie($self->login_path, $set_cookie_header);
	}
}

sub logout_handler {
	my ($self, $req, $dbh) = @_;

	my $passed_cookie_token = $req->cookies->{'auth_token'};
	warn sprintf("[SMSAuth LOGOUT] Processing logout for token: %s\n", $passed_cookie_token || '<NONE>');

	my $cookie_obj = CGI::Simple::Cookie->new(
		-name     => 'auth_token',
		-value    => ($passed_cookie_token || ''),
		-expires  => '-1y',
		-httponly => 1
	);

	my $expired_cookie = $cookie_obj ? $cookie_obj->as_string : '';

	if ($passed_cookie_token) {
		my $quoted = $dbh->quote($passed_cookie_token);
		$self->log_admin_event($dbh, $req, 'logout', $quoted);

		my $sql_delete_session = qq[DELETE FROM sms_auth WHERE cookie_token = $quoted];
		warn sprintf("[SMSAuth DB EXEC] %s\n", $sql_delete_session);
		my $rows = $dbh->do($sql_delete_session);
		warn sprintf("[SMSAuth DB RESULT] Deleted %s row(s)\n", $rows // '0');
	}

	warn sprintf("[SMSAuth LOGOUT] Session deleted. Redirecting to logged_out_path: %s\n", $self->logged_out_path);
	return $self->redirect_with_cookie($self->logged_out_path, $expired_cookie);
}

sub redirect_with_cookie {
	my ($self, $location, $cookie_header) = @_;
	warn sprintf("[SMSAuth REDIRECT] Redirecting to: '%s'%s\n", $location, $cookie_header ? " with Set-Cookie header" : "");
	
	my $res = Plack::Response->new(302);
	$res->headers->{Location} = $location;
	
	if ($cookie_header) {
		$res->headers->push_header('Set-Cookie' => $cookie_header);
	}
	
	return $res->finalize;
}

sub log_admin_event {
	my ($self, $dbh, $req, $action, $quoted_token) = @_;
	warn sprintf("[SMSAuth ADMIN LOG] Checking admin permissions for action: %s\n", $action);

	my $sql_admin_check = qq[
		SELECT a.name AS username, a.admin AS admin_group, s.remote_host, s.user_agent
		FROM access a, sms_auth s
		WHERE s.cookie_token LIKE $quoted_token
		  AND s.auth_state = 'sms_code_verified'
		  AND a.telephone = s.phone
		LIMIT 1
	];
	warn sprintf("[SMSAuth DB QUERY] Executing: %s\n", $sql_admin_check);
	my $sth = $dbh->prepare($sql_admin_check);
	$sth->execute;

	if (my $d = $sth->fetchrow_hashref) {
		if ($d->{admin_group}) {
			warn sprintf("[SMSAuth ADMIN LOG] User '%s' is admin (%s). Writing accounts_log entry\n", $d->{username}, $d->{admin_group});
			
			my $sql_log_insert = qq[
				INSERT INTO accounts_log
				(username, admin_group, type, info, remote_addr, user_agent, unix_time)
				VALUES (
					] . $dbh->quote($d->{username}) . qq[,
					] . $dbh->quote($d->{admin_group}) . qq[,
					'auth',
					] . $dbh->quote($action) . qq[,
					] . $dbh->quote($d->{remote_host}) . qq[,
					] . $dbh->quote($d->{user_agent}) . qq[,
					UNIX_TIMESTAMP()
				)
			];
			warn sprintf("[SMSAuth DB EXEC] %s\n", $sql_log_insert);
			my $rows = $dbh->do($sql_log_insert);
			warn sprintf("[SMSAuth DB RESULT] Inserted %s row(s) into accounts_log\n", $rows // '0');
		}
	} else {
		warn "[SMSAuth ADMIN LOG] User is not an admin or session not verified; skipping accounts_log entry\n";
	}
}

1;
