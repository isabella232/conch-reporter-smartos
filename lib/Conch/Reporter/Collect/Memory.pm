package Conch::Reporter::Collect::Memory;

use strict;
use warnings;

use Conch::Reporter::Collect::Memory::DIMM;

sub collect {
	my ($device) = @_;

	$device = Conch::Reporter::Collect::Memory::DIMM::collect($device);

	return $device;
}

1;
