package Conch::Reporter::Collect::Network::Interfaces;

use strict;
use warnings;

sub collect {
	my ( $device) = @_;

	$device = _macs($device);
	$device = _ip($device);
	$device = _links($device);
	$device = _mtu($device);

	return $device;
}

sub _ip {
	my ( $device ) = @_;
	my $cmd = `ipadm show-addr -p -o addrobj,addr`;
	# lo0/v4:127.0.0.1/8
	# ixgbe3/_a:10.65.245.20/24
	# external0/_a:10.65.246.20/24
	# lo0/v6:\:\:1/128

	foreach my $line (split/\n/, $cmd) {
		chomp $line;
		my ($iface,$ipaddr) = split/:/, $line;
		next if $iface =~ /lo0/;
		$iface =~ s/\/.*$//g;

		$device->{interfaces}{$iface}{ipaddr} = $ipaddr;
	}
	return $device;
}

sub _macs {
	my ( $device ) = @_;

	my $cmd = `dladm show-phys -m -p -o link,address`;
	# igb0:24\:6e\:96\:24\:2f\:5c
	# ixgbe3:24\:6e\:96\:24\:2f\:5a

	foreach my $line (split/\n/, $cmd) {
		chomp $line;

		# bdha is bad at regexp.
		$line =~ s/\\:/-/g;
		my ($iface, $mac) = split/:/, $line;
		$mac =~ s/-/:/g;

		$device->{interfaces}{$iface}{mac} = $mac;
	}

	return $device;
}

sub _links {
	my ( $device ) = @_;

	my $cmd = `dladm show-phys -p -o link,state,speed,duplex`;
	# igb0:down:0:half
	# igb1:down:0:half
	# ixgbe0:up:10000:full
	# ixgbe2:up:10000:full
	# ixgbe1:up:10000:full
	# ixgbe3:up:10000:full

	# $device->{interfaces}{$iface}{state}  = $state;

	return $device;
}

sub _mtu {
	my ( $device ) = @_;
	# dladm show-link -p -o link,class,mtu,state | grep phys
	# igb0:phys:1500:down
	# igb1:phys:1500:down
	# ixgbe0:phys:1500:up
	# ixgbe2:phys:1500:up
	# ixgbe1:phys:1500:up # ixgbe3:phys:1500:up

#	$device->{interfaces}{$iface}{mtu}    = $mtu;
}

1;