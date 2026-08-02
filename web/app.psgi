use strict;
use warnings;
use Plack::Builder;
use Plack::Request;

use SMSAuth;

my $app = sub {
	my $env = shift;
	my $req = Plack::Request->new($env);

	return [
		200,
		[ 'Content-Type' => 'text/html; charset=utf-8' ],
		[ "<html><body><h1>Authenticated Area</h1><p>Accessed path: " . $req->path_info . "</p></body></html>" ]
	];
};

# Wrap app directly using the instantiated SMSAuth object
$app = SMSAuth->new(
	login_path        => '/private/login.html',
	sms_code_path     => '/private/sms_code.html',
	logged_out_path   => '/logged_out.html',
	logout_path       => 'logout',
	default_path      => '/',
	public_access     => '/public,/login_static.css',
	user_admin_access => '/admin'
)->wrap($app);
