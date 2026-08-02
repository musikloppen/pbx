use strict;
use warnings;
use Plack::Builder;
use Plack::App::File;

use SMSAuth;

my $root_dir = '/var/www/www';

# 1. Base static file app
my $file_app = Plack::App::File->new(
	root => $root_dir
)->to_app;

# 2. Inner app: Rewrites directories to index.html ONLY after passing auth
my $protected_app = sub {
	my $env = shift;
	my $path = $env->{PATH_INFO} || '/';

	# If target path on disk is a directory, append index.html
	if (-d ($root_dir . $path)) {
		$path .= '/' unless $path =~ m{/$};
		$env->{PATH_INFO} = "${path}index.html";
	}

	return $file_app->($env);
};

# 3. Outer SMSAuth authentication middleware (intercepts EVERYTHING first)
my $app = SMSAuth->new(
	default_path      => '/',
	login_path        => '/private/login.html',
	logged_out_path   => '/logged_out.html',
	sms_code_path     => '/private/sms_code.html',
	public_access     => '/logged_out.html, /404.html',
)->wrap($protected_app);

return $app;
