#!/opt/tools/bin/perl

use lib './local/lib/perl5';
use lib './lib';

use strict;
use warnings;

use JSON;
use Data::Printer;

use Conch::Reporter::Collect;
use Conch::Reporter::Collect::Network;

my $device = {};

$device = Conch::Reporter::Collect::Network::collect($device);

p $device;
