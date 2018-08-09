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

	my %vendors = (
		arista => [ "" ],
		dell   => [ "" ],
	);

	my $cmd;
	if ( -f "/var/tmp/lldp.out" ) {
		$cmd = `cat /var/tmp/lldp.out`;
	} else {
		# This can take up to 60s to run. It doesn't give us some useful
		# information like peer_descr or peer_text, but neither does
		# lldpneighbors.
		$cmd = `/var/tmp/dc-standup/get_link_lldp.sh`;
	}

	# 8TYJRD2,ixgbe0,a0:36:9f:c0:fb:b8,TenGigabitEthernet 1/1,va1-3-d05-2

	foreach my $line (split/\n/, $cmd) {
		my ($serial, $iface, $mac, $port, $switch) = split/,/, $line;
		$device->{interfaces}{$iface}{peer_port}   = $port;
		$device->{interfaces}{$iface}{peer_switch} = $switch;
		$device->{interfaces}{$iface}{peer_mac}    = $mac;
	}

	return $device;
}

1;
