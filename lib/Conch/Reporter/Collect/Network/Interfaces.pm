package Conch::Reporter::Collect::Network::Interfaces;

use strict;
use warnings;


use IPC::Cmd qw[can_run run run_forked];
use Conch::Reporter::Collect::OUI;

sub collect {
	my ( $device) = @_;

	$device = _macs($device); $device = _ip($device); $device = _links($device);
	$device = _mtu($device);
	$device = _product($device);

	return $device;
}

sub _product {
	my ( $device ) = @_;

	my $hw_pci = $device->{hwgrok}->{'pci-devices'};

	foreach my $iface (keys %{$device->{conch}->{interfaces}}) {
		my $driver = $iface;
		$driver =~ s/\d//g;
		foreach my $pci (@{$hw_pci}) {
			if ($pci->{'device-driver-name'} eq $driver) {
				$device->{conch}->{interfaces}->{$iface}->{product} =
					$pci->{'pci-device-name'};
			} else {
				$device->{conch}->{interfaces}->{$iface}->{product} =
					"unknown";
			}
		}
	}

	return $device;
}

sub _ip {
	my ( $device ) = @_;
	# lo0/v4:127.0.0.1/8
	# ixgbe3/_a:10.65.245.20/24
	# external0/_a:10.65.246.20/24
	# lo0/v6:\:\:1/128
	my $cmd = "ipadm show-addr -p -o addrobj,addr";
	my $buffer;
	scalar run( command => $cmd,
		verbose => 0,
		buffer  => \$buffer,
		timeout => 20);

	foreach my $line (split/\n/, $buffer) {
		chomp $line;
		my ($iface,$ipaddr) = split/:/, $line;
		next if $iface =~ /lo0/;
		$iface =~ s/\/.*$//g;

		$device->{conch}{interfaces}{$iface}{ipaddr} = $ipaddr;
	}
	return $device;
}

sub _macs {
	my ( $device ) = @_;

	# igb0:24\:6e\:96\:24\:2f\:5c
	# ixgbe3:24\:6e\:96\:24\:2f\:5a
	my $cmd = "dladm show-phys -m -p -o link,address";
	my $buffer;
	scalar run( command => $cmd,
		verbose => 0,
		buffer  => \$buffer,
		timeout => 20);

	foreach my $line (split/\n/, $buffer) {
		chomp $line;

		my ($iface, $mac) = split(/:/, $line,2);
		$mac =~ s/\\//g;

		$device->{conch}{interfaces}{$iface}{mac} = $mac;

		my $vendor = Conch::Reporter::Collect::OUI::lookup($mac);
		$device->{conch}{interfaces}{$iface}{vendor} = $vendor || undef;
	}

	return $device;
}

sub _links {
	my ( $device ) = @_;

	# igb0:down:0:half
	# ixgbe0:up:10000:full
	my $cmd = "dladm show-phys -p -o link,state,speed,duplex";
	my $buffer;
	scalar run( command => $cmd,
		verbose => 0,
		buffer  => \$buffer,
		timeout => 20);

	foreach my $line (split/\n/, $buffer) {
		chomp $line;

		my ($iface,$state,$speed,$duplex) = split/:/, $line;

		$device->{conch}{interfaces}{$iface}{state}  = $state;
		$device->{conch}{interfaces}{$iface}{duplex} = $duplex;
		$device->{conch}{interfaces}{$iface}{speed}  = $speed;
	}

	return $device;
}

sub _mtu {
	my ( $device ) = @_;

	# igb0:phys:1500:down
	# ixgbe0:phys:1500:up
	# external0:vnic:1500:up
	# net0:vnic:1500:?
	# net1:vnic:1500:?
	my $cmd = "dladm show-link -p -o link,class,mtu,state";
	my $buffer;
	scalar run( command => $cmd,
		verbose => 0,
		buffer  => \$buffer,
		timeout => 20);

	foreach my $line (split/\n/, $buffer) {
		next if $line=~ /^net.:/; # These are guest VNICs. Ignore them.
		chomp $line;

		my ($iface,$class,$mtu,$state) = split/:/, $line;

		$device->{conch}{interfaces}{$iface}{mtu}    = $mtu;
		$device->{conch}{interfaces}{$iface}{class}  = $class;
		$device->{conch}{interfaces}{$iface}{state}  = $state;
	}

	return $device;
}

1;
