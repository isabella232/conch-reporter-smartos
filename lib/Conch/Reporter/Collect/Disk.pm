package Conch::Reporter::Collect::Disk;

use strict;
use warnings;

use Conch::Reporter::Collect::Disk::Diskinfo;
use Conch::Reporter::Collect::Disk::Inventory;
use Conch::Reporter::Collect::Disk::HBA;

sub collect {
	my ($device) = @_;

	$device = Conch::Reporter::Collect::Disk::Diskinfo::collect($device);
	$device = Conch::Reporter::Collect::Disk::Smartctl::collect($device);
	$device = Conch::Reporter::Collect::Disk::Inventory::collect($device);
	$device = Conch::Reporter::Collect::Disk::HBA::collect($device);

	return $device;
}

1;
