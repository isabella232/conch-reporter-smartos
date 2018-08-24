package Conch::Reporter::Collect::Network;

use strict;
use warnings;

use Conch::Reporter::Collect::OUI;

use Conch::Reporter::Collect::Network::Interfaces;
use Conch::Reporter::Collect::Network::IPMI;
use Conch::Reporter::Collect::Network::Peers;

sub collect {
	my ($device) = @_;

	print "=> Interfaces\n";
	$device = Conch::Reporter::Collect::Network::Interfaces::collect($device);

	print "=> IPMI\n";
	$device = Conch::Reporter::Collect::Network::IPMI::collect($device);

	print "=> Network peers\n";
	$device = Conch::Reporter::Collect::Network::Peers::collect($device);

	return $device;
}

1;
