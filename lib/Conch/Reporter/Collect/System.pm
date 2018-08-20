package Conch::Reporter::Collect::System;

use strict;
use warnings;

use Conch::Reporter::Collect::System::Uptime;

sub collect {
	my ($device) = @_;

	print "=> Uptime\n";
	$device = Conch::Reporter::Collect::System::Uptime::collect($device);

	return $device;
}

1;
