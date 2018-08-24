#!/opt/tools/bin/perl

use lib './local/lib/perl5';
use lib './lib';

use strict;
use warnings;

use JSON::PP;
use Path::Tiny;
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
use UUID::Tiny ':std';

use Conch::Reporter::Collect;
use Conch::Reporter::Collect::hwgrok;
use Conch::Reporter::Collect::System;
use Conch::Reporter::Collect::Network;
use Conch::Reporter::Collect::Memory;
use Conch::Reporter::Collect::Disk;

my $device = {};

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
