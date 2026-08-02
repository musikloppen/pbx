use strict;
use warnings;
use Plack::Builder;
use Plack::App::File;

use SMSAuth;

# 1. Base application: serves any file on disk out of /var/www/www
# Plack::App::File automatically handles MIME types, streaming, and 404s
my $app = Plack::App::File->new(
	root  => '/var/www/www',
	index => ['index.html', 'index.htm', 'admin.epl']
)->to_app;

# 2. Outer SMSAuth authentication middleware
# Intercepts every request first:
# - Unauthenticated -> Executes state machine / redirects
# - Authenticated   -> Passes through to Plack::App::File to serve the requested path
$app = SMSAuth->new(
	default_path      => '/',
	login_path        => '/private/login.html',
	logged_out_path   => '/logged_out.html',
	sms_code_path     => '/private/sms_code.html',
	public_access     => '/logged_out.html, /404.html',
)->wrap($app);

return $app;
