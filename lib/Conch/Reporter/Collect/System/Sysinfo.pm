package Conch::Reporter::Collect::System::Sysinfo;

use strict;
use warnings;

use JSON;

# Note: sysinfo is already cache aware, so no need for us to implement one
# ourselves.

sub collect {
	my ($device) = @_;

	$device = _load_sysinfo($device);
	$device = _cpu_info($device);

	return $device;
}

sub _load_sysinfo {
	my ($device) = @_;

	my $sysinfo = `/usr/bin/sysinfo`;
	$device->{sysinfo} = decode_json $sysinfo;

	return $device;
}

sub _cpu_info {
	my ($device) = @_;

	$device->{conch}->{processor}->{count} =
		$device->{sysinfo}->{'CPU Physical Cores'};

	$device->{conch}->{processor}->{type} = $device->{sysinfo}->{'CPU Type'};

	return $device;
}

1;
