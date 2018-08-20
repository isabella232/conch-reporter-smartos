package Conch::Reporter::Collect::System;

use strict;
use warnings;

use Conch::Reporter::Collect::System::SMBIOS;
use Conch::Reporter::Collect::System::Sysinfo;
use Conch::Reporter::Collect::System::Power;
use Conch::Reporter::Collect::System::Sensors;
use Conch::Reporter::Collect::System::Fans;

sub collect {
	my ($device) = @_;

	print "=> Sysinfo\n";
	$device = Conch::Reporter::Collect::System::Sysinfo::collect($device);

	print "=> SMBIOS\n";
	$device = Conch::Reporter::Collect::System::SMBIOS::collect($device);

	print "=> Power\n";
	$device = Conch::Reporter::Collect::System::Power::collect($device);

	print "=> Sensors\n";
	$device = Conch::Reporter::Collect::System::Sensors::collect($device);

	print "=> Fans\n";
	$device = Conch::Reporter::Collect::System::Fans::collect($device);

	return $device;
}

1;
