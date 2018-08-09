package Conch::Reporter::Collect::Network::Peers;

use strict;
use warnings;

sub collect {
	my ($device) = @_;

	$device = _peers($device);

	return $device;
}

sub _peers {
	my ($device) = @_;
	return $device;
}

1;
