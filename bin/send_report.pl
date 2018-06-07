use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Data::Printer;
use Conch::Reporter;

my $device_report = collect_report();
p  $device_report;

publish_report($device_report);

