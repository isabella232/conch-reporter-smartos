package Conch::Reporter::Collect::Network::Peers;

use strict;
use warnings;

use JSON::PP;
use Path::Tiny;
use File::stat;
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
use Hash::Merge;
use IPC::Cmd qw[can_run run run_forked];

use Conch::Reporter::Collect::OUI;

sub collect {
	my ($device) = @_;

	$device = _load_lldp_cache($device);

	return $device;
}

sub _load_lldp_cache {
	my ($device) = @_;

	my $file = "/tmp/lldp.json";
	my $update_interval = 60 * 60; # Every hour
	my $fp = path($file);
	my $lldp;

	if ( -f $file ) {
		my $t0 = [gettimeofday];

		my $json = $fp->slurp_utf8;
		$lldp = decode_json $json;

		my $sb = stat($file);

		if ( (time() - $sb->mtime) > $update_interval) {
			print "=> Updating existing lldp cache:\n";
			$device = _peers($device);
			$fp->spew_utf8(encode_json $device->{conch}->{interfaces});
		} else {
			# Caches are great, but let's not blow away any local changes we
			# have not involving LLDP from the cache.
			print "=> Using existing lldp cache: ";
			my $merge = Hash::Merge->new('LEFT_PRECEDENT');
			my %merged_iface =
				%{ $merge->merge( $device->{conch}->{interfaces}, $lldp ) };

			$device->{conch}->{interfaces} = \%merged_iface;
		}

		my $elapsed = tv_interval ($t0);

		printf "=> %.2fs\n", $elapsed;
	} else {
		print "=> lldp cache not found, creating:\n";
		my $t0 = [gettimeofday];
		$device = _peers($device);
		$fp->spew_utf8(encode_json $device->{conch}->{interfaces});
		my $elapsed = tv_interval ($t0);
		printf "=> %.2fs\n", $elapsed;
	}

	return $device;

}

sub _snoop_lldp {
	my ($iface) = @_;

	print "==> Snooping LLDP on $iface: ";

	# device-id: f4:8e:38:46:23:22
	# platform: 
	# capabilities: 
	# port-id: TenGigabitEthernet 1/1
	# portDesc: 
	# sysName: va1-3-d05-2
	# mgmt-address: 

	my $lldp = {};

	my $cmd = "./bin/getldp.pl -x -s -i $iface -l -t 60";

	my $t0 = [gettimeofday];

	my( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) =
		run( command => $cmd, verbose => 0, timeout => 45 );

	my $elapsed = tv_interval ($t0);
	printf "%.2fs\n", $elapsed;

	foreach my $line (split/\n/, $stdout_buf->[0]) {
		chomp $line;
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

	foreach my $iface (keys %{$device->{conch}{interfaces}}) {
		next unless $device->{conch}{interfaces}{$iface}{state};
		next unless $device->{conch}{interfaces}{$iface}{class};
		next unless $device->{conch}{interfaces}{$iface}{state} eq "up";
		next unless $device->{conch}{interfaces}{$iface}{class} eq "phys";

		my $lldp = _snoop_lldp($iface);
		foreach my $k (keys %{$lldp}) {
			if ($field_map{$k}) {
				my $remap = $field_map{$k};
				$device->{conch}{interfaces}{$iface}{$remap} = $lldp->{$k};
			} else {
				$device->{conch}{interfaces}{$iface}{$k} = $lldp->{$k};
			}
		}

		if ($device->{conch}{interfaces}{$iface}{peer_mac}) {
			my $peer_mac = $device->{conch}{interfaces}{$iface}{peer_mac};
			my $vendor = Conch::Reporter::Collect::OUI::lookup($peer_mac);
			$device->{conch}{interfaces}{$iface}{peer_vendor} = $vendor;
		}
	}

	return $device;
}

1;
