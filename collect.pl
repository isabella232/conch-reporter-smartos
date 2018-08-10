#!/opt/tools/bin/perl

use lib './local/lib/perl5';
use lib './lib';

use strict;
use warnings;

use JSON;
use Path::Tiny;
use Data::Printer;

use Conch::Reporter::Collect;
use Conch::Reporter::Collect::hwgrok;
use Conch::Reporter::Collect::Network;

my $device = {};

print "Starting run\n";
print "Collector: hwgrok\n";
$device = Conch::Reporter::Collect::hwgrok::collect($device);

print "Collector: network\n";
$device = Conch::Reporter::Collect::Network::collect($device);

my $json = encode_json $device;
my $file = "/tmp/conch-report.json";
my $fp = path($file);
$fp->spew_utf8($json);
