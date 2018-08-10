package Conch::Reporter::Collect::Network::Peers;

use strict;
use warnings;

use Conch::Reporter::Collect::OUI;

sub collect {
	my ($device) = @_;

	$device = _peers($device);

	return $device;
}

sub _snoop_lldp {
	my ($iface) = @_;

	# device-id: f4:8e:38:46:23:22
	# platform: 
	# capabilities: 
	# port-id: TenGigabitEthernet 1/1
	# portDesc: 
	# sysName: va1-3-d05-2
	# mgmt-address: 

	my $lldp = {};

	my $cmd = `./getldp.pl -x -s -i $iface -l -t 60 2>> /tmp/getldp.out`;

	foreach my $line (split/\n/, $cmd) {
		my ($k, $v) = split(/:/, $line, 2);
		$k =~ s/^\s+|\s+$//g;
		$v =~ s/^\s+|\s+$//g if $v;

		$lldp->{$k} = $v || undef;
	}

	return $lldp;
}

sub _peers {
	my ($device) = @_;

	my %field_map = (
		'device-id'    => 'peer_mac',
		'port-id'      => 'peer_port',
		'portDesc'     => 'peer_port_descr',
		'sysName'      => 'peer_switch',
		'mgmt-address' => 'peer_mgmt_ip',
		'platform'     => 'peer_descr',
		'capabilities' => 'peer_capabilities',
	);

	foreach my $iface (keys %{$device->{interfaces}}) {
		next unless $device->{interfaces}{$iface}{state};
		next unless $device->{interfaces}{$iface}{class};
		next unless $device->{interfaces}{$iface}{state} eq "up";
		next unless $device->{interfaces}{$iface}{class} eq "phys";

		my $lldp = _snoop_lldp($iface);
		foreach my $k (keys %{$lldp}) {
			if ($field_map{$k}) {
				my $remap = $field_map{$k};
				$device->{interfaces}{$iface}{$remap} = $lldp->{$k};
			} else {
				$device->{interfaces}{$iface}{$k} = $lldp->{$k};
			}
		}

		if ($device->{interfaces}{$iface}{peer_mac}) {
			my $peer_mac = $device->{interfaces}{$iface}{peer_mac};
			my $lookup = Conch::Reporter::Collect::OUI::lookup($peer_mac);
			my $vendor = $lookup->[0] || undef;
			$device->{interfaces}{$iface}{peer_vendor} = $vendor;
		}
	}

	return $device;
}

1;
