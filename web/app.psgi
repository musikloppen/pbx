use strict;
use warnings;
use Plack::Builder;
use Plack::App::Proxy;
use Plack::App::File;

use SMSAuth;

my $root_dir = '/var/www/www';
my $backend = 'http://backend:80';

# 1. Primary backend proxy (targets the internal backend web server)
my $upstream_backend = Plack::App::Proxy->new(
	remote => $backend,
)->to_app;

# 2. Local static file responder (for /auth/ login forms)
my $local_file_app = Plack::App::File->new(
	root => $root_dir
)->to_app;

# 3. Inner router: Serves /auth/ pages locally, proxies authenticated traffic to backend
my $inner_app = sub {
	my $env = shift;
	my $path = $env->{PATH_INFO} || '/';

	# Serve local authentication forms and public static assets from local container disk
	if ($path =~ m{^/auth/} || $path eq '/logged_out.html' || $path eq '/404.html') {
		return $local_file_app->($env);
	}

	# Proxy authenticated requests to the internal backend service
	return $upstream_backend->($env);
};

# 4. Outer SMSAuth authentication middleware
my $app = SMSAuth->new(
	default_path      => '/',
	login_path        => '/auth/login.html',
	logged_out_path   => '/logged_out.html',
	sms_code_path     => '/auth/sms_code.html',
	public_access     => '/logged_out.html, /404.html',
)->wrap($inner_app);

return $app;
