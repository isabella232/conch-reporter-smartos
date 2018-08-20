package Conch::Reporter::Collect::System;

use strict;
use warnings;

use Conch::Reporter::Collect::System::Uptime;
use Conch::Reporter::Collect::System::SMBIOS;
use Conch::Reporter::Collect::System::Sysinfo;

sub collect {
	my ($device) = @_;

	print "=> Sysinfo\n";
	$device = Conch::Reporter::Collect::System::Sysinfo::collect($device);

	print "=> SMBIOS\n";
	$device = Conch::Reporter::Collect::System::SMBIOS::collect($device);

	return $device;
}

1;
