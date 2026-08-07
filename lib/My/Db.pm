package My::Db;

use strict;
use warnings;
use utf8;
use DBI;

use Exporter 'import';
our @EXPORT_OK = qw( connect );

sub connect {
	my (%opts) = @_;

	my $db_host = $ENV{DB_HOST}        || 'pbx-db';
	my $db_port = $ENV{DB_PORT}        || 3306;
	my $db_name = $ENV{DB_NAME}        || 'pbx';
	my $db_user = $ENV{DB_USER}        || 'pbx';
	my $db_pass = $ENV{DB_PASSWORD}    || '';

	my $raise_error = exists $opts{RaiseError} ? $opts{RaiseError} : 0;
	my $print_error = exists $opts{PrintError} ? $opts{PrintError} : 0;

	my $dsn = "DBI:MariaDB:database=$db_name;host=$db_host;port=$db_port";
	my $dbh = DBI->connect(
		$dsn,
		$db_user,
		$db_pass,
		{
			RaiseError             => $raise_error,
			PrintError             => $print_error,
			AutoCommit             => 1,
			mariadb_auto_reconnect => 1,
		}
	);

	if (!$dbh) {
		warn sprintf("[My::Db ERROR] Connection failed to %s at %s:%s: %s\n",
			$db_name, $db_host, $db_port, $DBI::errstr || 'Unknown error');
	}

	return $dbh;
}

1;
