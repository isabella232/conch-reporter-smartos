package Conch::Reporter::Collect::Disk;

use strict;
use warnings;

use Conch::Reporter::Collect::Disk::Diskinfo;
use Conch::Reporter::Collect::Disk::Inventory;

sub collect {
	my ($device) = @_;

	$device = Conch::Reporter::Collect::Disk::Diskinfo::collect($device);
	$device = Conch::Reporter::Collect::Disk::Smartctl::collect($device);
	$device = Conch::Reporter::Collect::Disk::Inventory::collect($device);

	return $device;
}

1;
