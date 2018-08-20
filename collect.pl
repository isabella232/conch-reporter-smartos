#!/opt/tools/bin/perl

use lib './local/lib/perl5';
use lib './lib';

use strict;
use warnings;

use JSON;
use Path::Tiny;
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
use UUID::Tiny ':std';

use Data::Printer;

use Conch::Reporter::Collect;
use Conch::Reporter::Collect::hwgrok;
use Conch::Reporter::Collect::Network;
use Conch::Reporter::Collect::Memory;
use Conch::Reporter::Collect::Disk;

my $device = {};

print "Starting run\n";

my $t0 = [gettimeofday];

print "Collector: hwgrok\n";
$device = Conch::Reporter::Collect::hwgrok::collect($device);

print "Collector: network\n";
$device = Conch::Reporter::Collect::Network::collect($device);

print "Collector: memory\n";
$device = Conch::Reporter::Collect::Memory::collect($device);

print "Collector: disk\n";
$device = Conch::Reporter::Collect::Disk::collect($device);

$device->{conch}->{report_id} = create_uuid_as_string();

my $json = encode_json $device;
my $file = "/tmp/conch-report.json";
my $fp = path($file);
$fp->spew_utf8($json);

my $elapsed = tv_interval ($t0);
printf "Run complete: %.2fs\n", $elapsed;
