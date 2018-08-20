package Conch::Reporter::Collect::System;

use strict;
use warnings;

use Conch::Reporter::Collect::System::Uptime;
use Conch::Reporter::Collect::System::SMBIOS;

sub collect {
	my ($device) = @_;

	print "=> Uptime\n";
	$device = Conch::Reporter::Collect::System::Uptime::collect($device);

	print "=> SMBIOS\n";
	$device = Conch::Reporter::Collect::System::SMBIOS::collect($device);

	return $device;
}

1;
