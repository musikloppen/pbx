#!/usr/bin/perl -w

use strict;
use Data::Dumper;
use DBI;

my $caller_id = $ARGV[0];
my $event = $ARGV[1];

my $dbi = 'DBI:mysql:database=$MYSQL_DATABASE;host=db;port=3306';

my $dbh = DBI->connect($dbi, '$MYSQL_USER', '$MYSQL_PASSWORD', { mysql_auto_reconnect => 1, mysql_enable_utf8 => 1 }) || die $!;

my $quoted_caller_id = $dbh->quote($caller_id);
my $quoted_event = $dbh->quote($event);

$dbh->do(qq[INSERT INTO log (`caller_id`, `event`, `unix_time`) VALUES ($quoted_caller_id, $quoted_event, UNIX_TIMESTAMP())]) || warn $!;

1;
