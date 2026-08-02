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

# Internal DB connector reading from Docker container environment
sub _get_dbh {
	my $db_host = $ENV{DB_HOST} || 'pbx-db';
	my $db_name = $ENV{DB_NAME} || 'pbx';
	my $db_user = $ENV{DB_USER} || 'pbx';
	my $db_pass = $ENV{DB_PASS} || '';

	return DBI->connect(
		"DBI:mysql:database=$db_name;host=$db_host",
		$db_user,
		$db_pass,
		{ RaiseError => 0, PrintError => 0, AutoCommit => 1, mysql_enable_utf8 => 1 }
	);
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
}

sub call {
	my ($self, $env) = @_;
	my $req = Plack::Request->new($env);

	my $orig_uri = $req->request_uri;
	my $path     = $req->path_info;

	# Bypass snooze page/API paths if configured
	if ($self->snooze_page && $orig_uri =~ /^${\$self->snooze_page}/) {
		return $self->app->($env);
	}
	if ($self->snooze_api && $orig_uri =~ /^${\$self->snooze_api}/) {
		return $self->app->($env);
	}

	# Bypass configured public paths
	foreach my $pub (@{ $self->public_access }) {
		if ($path eq $pub) {
			return $self->app->($env);
		}
	}

	if ($path eq $self->logged_out_path) {
		return $self->app->($env);
	}

	my $dbh = _get_dbh();
	unless ($dbh) {
		my $res = Plack::Response->new(503);
		$res->headers({ 'Retry-After' => '60' });
		$res->body("Service Unavailable: Database Connection Failed");
		return $res->finalize;
	}

	if (index($orig_uri, $self->logout_path) >= 0) {
		return $self->logout_handler($req, $dbh);
	}

	return $self->login_handler($req, $dbh, $env);
}

sub login_handler {
	my ($self, $req, $dbh, $env) = @_;

	my $cookies = $req->cookies;
	my $passed_cookie_token = $cookies->{'auth_token'};

	my $cookie_token;
	my $set_cookie_header;

	if ($passed_cookie_token) {
		$cookie_token = $passed_cookie_token;
	} else {
		$cookie_token = unpack('H*', join('', map { chr(int Math::Random::Secure::rand(256)) } 1 .. 16));
		$set_cookie_header = CGI::Simple::Cookie->new(
			-name     => 'auth_token',
			-value    => $cookie_token,
			-expires  => '+1y',
			-httponly => 1,
			-secure   => 0
		)->as_string;
	}

	my $quoted_token = $dbh->quote($passed_cookie_token || $cookie_token);
	my $sth = $dbh->prepare(qq[SELECT `auth_state` FROM sms_auth WHERE cookie_token LIKE $quoted_token LIMIT 1]);
	$sth->execute;

	if (my $d = $sth->fetchrow_hashref) {
		my $state = lc($d->{auth_state} || '');

		if ($state eq 'new') {
			$dbh->do(qq[UPDATE sms_auth SET auth_state = 'login', unix_time = ] . time() . qq[ WHERE cookie_token = $quoted_token]);
			return $self->redirect_with_cookie($self->login_path, $set_cookie_header);
		}
		elsif ($state eq 'login') {
			my $phone = $req->param('id');
			my $user_is_in_db = 0;

			if ($phone) {
				my $quoted_phone = $dbh->quote($phone);
				my $s1 = $dbh->prepare(qq[SELECT `sms_notification` FROM meters WHERE FIND_IN_SET($quoted_phone, `sms_notification`) > 0 LIMIT 1]);
				$s1->execute;
				$user_is_in_db = $s1->rows;

				my $s2 = $dbh->prepare(qq[SELECT `phone` FROM users WHERE FIND_IN_SET($quoted_phone, `phone`) > 0 LIMIT 1]);
				$s2->execute;
				$user_is_in_db ||= $s2->rows;
			}

			if ($user_is_in_db) {
				my $sms_code = join('', map { int(Math::Random::Secure::rand(10)) } 1 .. 6);
				$dbh->do(qq[UPDATE sms_auth SET `auth_state` = 'sms_code_sent', `sms_code` = ] . $dbh->quote($sms_code) . qq[, `phone` = ] . $dbh->quote($phone) . qq[, unix_time = ] . time() . qq[ WHERE cookie_token = $quoted_token]);

				my $session_cookie = CGI::Simple::Cookie->new(
					-name     => 'auth_token',
					-value    => $cookie_token,
					-httponly => 1,
					-secure   => 0
				)->as_string;

				return $self->redirect_with_cookie($self->sms_code_path, $session_cookie);
			} else {
				$env->{PATH_INFO} = $self->login_path;
				return $self->app->($env);
			}
		}
		elsif ($state eq 'sms_code_sent') {
			my $sms_code       = $req->param('sms_code');
			my $stay_logged_in = $req->param('stay_logged_in');

			my $cookie_opts = { -name => 'auth_token', -value => $passed_cookie_token, -httponly => 1, -secure => 0 };
			$cookie_opts->{-expires} = '+1y' if $stay_logged_in;
			my $auth_cookie = CGI::Simple::Cookie->new(%$cookie_opts)->as_string;

			my $c_sth = $dbh->prepare(qq[SELECT `sms_code`, `orig_uri` FROM sms_auth WHERE `cookie_token` LIKE $quoted_token AND `sms_code` LIKE ] . $dbh->quote($sms_code) . qq[ LIMIT 1]);
			$c_sth->execute;

			if (my $cd = $c_sth->fetchrow_hashref) {
				$dbh->do(qq[UPDATE sms_auth SET `auth_state` = 'sms_code_verified', `session` = ] . ($stay_logged_in ? 0 : 1) . qq[, unix_time = ] . time() . qq[ WHERE cookie_token = $quoted_token]);
				
				$self->log_admin_event($dbh, $req, 'login', $quoted_token);
				return $self->redirect_with_cookie($cd->{orig_uri}, $auth_cookie);
			} else {
				$env->{PATH_INFO} = $self->sms_code_path;
				return $self->app->($env);
			}
		}
		elsif ($state eq 'sms_code_verified') {
			$dbh->do(qq[UPDATE sms_auth SET unix_time = ] . time() . qq[ WHERE cookie_token = $quoted_token]);
			return $self->app->($env);
		}
	}
	else {
		my $remote_host = $req->header('X-Real-IP') || $req->header('X-Forwarded-For') || $req->address;
		my $user_agent  = $req->user_agent;

		my $target_uri = $req->request_uri;
		if ($target_uri =~ /${\$self->login_path}|${\$self->logout_path}|${\$self->logged_out_path}|${\$self->sms_code_path}/) {
			$target_uri = $self->default_path;
		}

		$dbh->do(qq[
			INSERT INTO sms_auth (cookie_token, auth_state, orig_uri, remote_host, user_agent, unix_time)
			VALUES (] . $dbh->quote($cookie_token) . qq[, 'new', ] . $dbh->quote($target_uri) . qq[, ] . $dbh->quote($remote_host) . qq[, ] . $dbh->quote($user_agent) . qq[, ] . time() . qq[)
		]);

		return $self->redirect_with_cookie($self->login_path, $set_cookie_header);
	}
}

sub logout_handler {
	my ($self, $req, $dbh) = @_;

	my $passed_cookie_token = $req->cookies->{'auth_token'};
	my $expired_cookie = CGI::Simple::Cookie->new(
		-name    => 'auth_token',
		-value   => $passed_cookie_token,
		-expires => '-1y',
		-httponly=> 1
	)->as_string;

	if ($passed_cookie_token) {
		my $quoted = $dbh->quote($passed_cookie_token);
		$self->log_admin_event($dbh, $req, 'logout', $quoted);
		$dbh->do(qq[DELETE FROM sms_auth WHERE cookie_token = $quoted]);
	}

	return $self->redirect_with_cookie($self->logged_out_path, $expired_cookie);
}

sub redirect_with_cookie {
	my ($self, $location, $cookie_header) = @_;
	my $res = Plack::Response->new(302);
	$res->headers->{Location} = $location;
	$res->cookies->{auth_token} = $cookie_header if $cookie_header;
	return $res->finalize;
}

sub log_admin_event {
	my ($self, $dbh, $req, $action, $quoted_token) = @_;
	my $sth = $dbh->prepare(qq[
		SELECT u.username, u.admin_group, a.remote_host, a.user_agent
		FROM users u, sms_auth a
		WHERE a.cookie_token LIKE $quoted_token
		  AND a.auth_state = 'sms_code_verified'
		  AND u.phone = a.phone
		LIMIT 1
	]);
	$sth->execute;
	if (my $d = $sth->fetchrow_hashref) {
		if ($d->{admin_group}) {
			$dbh->do(qq[
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
			]);
		}
	}
}

1;
