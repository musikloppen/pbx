use strict;
use warnings;
use Plack::Builder;
use Plack::App::Proxy;
use Plack::App::File;

use SMSAuth;

my $root_dir = '/var/www/www';
my $backend  = $ENV{UPSTREAM_BACKEND} || 'http://web-backend:5000';

my $upstream_backend = Plack::App::Proxy->new(
	remote => $backend,
)->to_app;

my $local_file_app = Plack::App::File->new(
	root => $root_dir
)->to_app;

my $inner_app = sub {
	my $env  = shift;
	my $path = $env->{PATH_INFO} || '/';

	# Serve local authentication forms and public auth assets locally from ./sms-auth/www
	if ($path =~ m{^/auth/} || $path eq '/logged_out.html' || $path eq '/404.html') {
		return $local_file_app->($env);
	}

	# Forward ALL authenticated application traffic (e.g. /, /index.html, /api/unlock) to web-backend
	return $upstream_backend->($env);
};

my $app = SMSAuth->new(
	default_path    => '/',
	login_path      => '/auth/login.html',
	logged_out_path => '/logged_out.html',
	sms_code_path   => '/auth/sms_code.html',
	public_access   => '/logged_out.html, /404.html',
)->wrap($inner_app);

return $app;
