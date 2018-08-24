#!/usr/perl5/bin/perl

use lib ('./local/lib/perl5', './lib');

use strict;
use warnings;

use JSON::PP;
use Path::Tiny;
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
use UUID::Tiny ':std';
use MIME::Base64 qw(encode_base64);
use Fcntl qw( :DEFAULT :flock );

use Conch::Reporter::Collect;
use Conch::Reporter::Collect::hwgrok;
use Conch::Reporter::Collect::System;
use Conch::Reporter::Collect::Network;
use Conch::Reporter::Collect::Memory;
use Conch::Reporter::Collect::Disk;

my $device = {};

my $lockfile = "/var/tmp/conch-reporter.lock";

my $lock_fh;
sysopen $lock_fh, $lockfile, O_CREAT|O_WRONLY
  or die "couldn't open lockfile $lockfile: $!";

my $lock_flags = LOCK_EX | LOCK_NB;

unless (flock $lock_fh, $lock_flags) {
  my $error = $!;
  my $mtime = (stat $lock_fh)[9];
  my $stamp = scalar localtime $mtime;
  die "can't lock; $!; lockfile created $stamp";
}

printf $lock_fh "pid %s running %s\nstarted at %s\n",
  $$, $0, scalar localtime $^T;

print "Starting run\n";

my $t0 = [gettimeofday];

$device->{conch}->{report_id}    = create_uuid_as_string();
$device->{conch}->{version}      = "2";
$device->{conch}->{state}        = "ONLINE";
$device->{conch}->{device_type}  = "server";

print "Collector: hwgrok\n";
$device = Conch::Reporter::Collect::hwgrok::collect($device);

print "Collector: system\n";
$device = Conch::Reporter::Collect::System::collect($device);

print "Collector: network\n";
$device = Conch::Reporter::Collect::Network::collect($device);

print "Collector: memory\n";
$device = Conch::Reporter::Collect::Memory::collect($device);

print "Collector: disk\n";
$device = Conch::Reporter::Collect::Disk::collect($device);

print "Cleanup:\n";

# XXX Supporting anything other than phys will require changes to the
# DeviceReport ingestion and validation code.
foreach my $iface (keys %{$device->{conch}->{interfaces}}) {
	if ($device->{conch}->{interfaces}->{$iface}->{class} ne "phys") {
		print "=> Currently only support phys interfaces. Removing $iface from report.\n";
		delete $device->{conch}->{interfaces}->{$iface};
	}
}

my $json = encode_json $device;
my $file = "/tmp/conch-report.json";
my $fp = path($file);
$fp->spew_utf8($json);

my $elapsed = tv_interval ($t0);
printf "Run complete: %.2fs\n", $elapsed;
