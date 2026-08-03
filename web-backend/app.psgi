use strict;
use warnings;
use Plack::Builder;
use Plack::App::File;
use JSON::PP;
use IO::Socket::INET;

my $root_dir = '/var/www/html';

my $static_app = Plack::App::File->new(
	root => $root_dir
)->to_app;

# Helper function to read complete response blocks, handling stray AMI events
sub read_ami_response {
	my ($socket) = @_;
	my %response;
	my $in_block = 0;

	while (my $line = <$socket>) {
		$line =~ s/\r?\n$//;
		last if $line eq '' && $in_block;
		next if $line eq '';

		if ($line =~ /^Response:\s*(.+)/i) {
			$response{Response} = $1;
			$in_block = 1;
		} elsif ($line =~ /^Message:\s*(.+)/i) {
			$response{Message} = $1;
			$in_block = 1;
		} elsif ($line =~ /^Event:/i) {
			while (my $event_line = <$socket>) {
				$event_line =~ s/\r?\n$//;
				last if $event_line eq '';
			}
			next;
		}
	}
	return %response;
}

# Helper function to trigger Gate ring-to-open call via AMI Local Channel
sub trigger_ami_originate {
	my ($gate, $caller_id) = @_;

	my $ami_host = $ENV{ASTERISK_HOST}     || 'pbx';
	my $ami_port = $ENV{ASTERISK_AMI_PORT} || 5038;
	my $ami_user = $ENV{ASTERISK_AMI_USER} || 'pbxadmin';
	my $ami_pass = $ENV{ASTERISK_AMI_PASS} || 'pbxpass';

	my $exten   = ($gate == 2) ? 'gate2' : 'gate1';
	my $channel = "Local/${exten}\@myphones";

	my $socket = IO::Socket::INET->new(
		PeerHost => $ami_host,
		PeerPort => $ami_port,
		Proto    => 'tcp',
		Timeout  => 3,
	);

	unless ($socket) {
		warn "[AMI ERROR] Could not connect to Asterisk AMI at $ami_host:$ami_port - $@\n";
		return (0, "Failed to connect to Asterisk AMI");
	}

	# Read banner
	my $banner = <$socket>;

	# 1. Login Action
	print $socket "Action: Login\r\n";
	print $socket "Username: $ami_user\r\n";
	print $socket "Secret: $ami_pass\r\n\r\n";

	my %login_res = read_ami_response($socket);
	unless (($login_res{Response} || '') =~ /^Success/i) {
		close($socket);
		warn "[AMI ERROR] AMI Authentication Failed\n";
		return (0, "AMI authentication failed");
	}

	# 2. Originate Action using Application NoOp on Local Channel
	print $socket "Action: Originate\r\n";
	print $socket "Channel: $channel\r\n";
	print $socket "Application: NoOp\r\n";
	print $socket "CallerID: $caller_id\r\n";
	print $socket "Async: true\r\n\r\n";

	my %orig_res = read_ami_response($socket);
	my $originate_success = (($orig_res{Response} || '') =~ /^Success/i) ? 1 : 0;
	my $error_msg         = $orig_res{Message} || "Originate command failed";

	# 3. Logoff
	print $socket "Action: Logoff\r\n\r\n";
	read_ami_response($socket);
	close($socket);

	return ($originate_success, $originate_success ? "OK" : $error_msg);
}

my $app = sub {
	my $env  = shift;
	my $path = $env->{PATH_INFO} || '/';

	# Serve root path as index.html
	if ($path eq '/' || $path eq '/index.html') {
		$env->{PATH_INFO} = '/index.html';
		return $static_app->($env);
	}

	# --- API Endpoint: /api/unlock ---
	if ($path eq '/api/unlock' && $env->{REQUEST_METHOD} eq 'POST') {
		my $req_body = '';
		$env->{'psgi.input'}->read($req_body, $env->{CONTENT_LENGTH} || 0);

		my $data = eval { decode_json($req_body) } || {};
		my $gate = int($data->{gate} || 1);

		my $caller_id = $ENV{SIP_TRUNK_CALLER_ID} || '12345678';

		my ($success, $msg) = trigger_ami_originate($gate, $caller_id);

		if ($success) {
			my $res_body = encode_json({
				status    => 'ok',
				gate      => $gate,
				open_time => 3,
				user      => 'Authenticated'
			});

			return [
				200,
				['Content-Type' => 'application/json'],
				[$res_body]
			];
		} else {
			return [
				500,
				['Content-Type' => 'application/json'],
				[encode_json({ status => 'error', error => $msg })]
			];
		}
	}

	# Default static file routing from ./web-backend/www
	return $static_app->($env);
};

return $app;
