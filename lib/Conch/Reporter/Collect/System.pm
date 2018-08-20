package Conch::Reporter::Collect::System;

use strict;
use warnings;

use Conch::Reporter::Collect::System::Uptime;
use Conch::Reporter::Collect::System::SMBIOS;
use Conch::Reporter::Collect::System::Sysinfo;

sub collect {
	my ($device) = @_;

	print "=> Uptime\n";
	$device = Conch::Reporter::Collect::System::Uptime::collect($device);

	print "=> SMBIOS\n";
	$device = Conch::Reporter::Collect::System::SMBIOS::collect($device);

	print "=> Sysinfo\n";
	$device = Conch::Reporter::Collect::System::Sysinfo::collect($device);

	return $device;
}

1;
