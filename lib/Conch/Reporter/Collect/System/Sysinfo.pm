package Conch::Reporter::Collect::System::Sysinfo;

use strict;
use warnings;

use JSON;
use POSIX qw(strftime);

# Note: sysinfo is already cache aware, so no need for us to implement one
# ourselves.

sub collect {
	my ($device) = @_;

	$device = _load_sysinfo($device);

	$device = _serial_number($device);
	$device = _uptime_since($device);
	$device = _cpu_info($device);
	$device = _product($device);
	$device = _sku($device);
	$device = _system_uuid($device);
	$device = _hardware_family($device);
	$device = _hardware_version($device);
	$device = _operating_system($device);
	$device = _manufacturer($device);
	$device = _triton($device);

	return $device;
}

sub _load_sysinfo {
	my ($device) = @_;

	my $sysinfo = `/usr/bin/sysinfo`;
	$device->{sysinfo} = decode_json $sysinfo;

	return $device;
}

sub _uptime_since {
	my ($device) = @_;

	# "uptime_since": "2018-08-20 18:33:41+00:00",
	my $boot_time = $device->{sysinfo}->{'Boot Time'};
	my $fmt_uptime = strftime("%Y-%m-%d %H:%M:%S%z",localtime($boot_time));

	$device->{conch}->{uptime_since} = $fmt_uptime || undef;

	return $device;
}

sub _serial_number {
	my ($device) = @_;

	$device->{conch}->{serial_number} =
		$device->{sysinfo}->{'Serial Number'} || undef;

	return $device;
}

sub _cpu_info {
	my ($device) = @_;

	$device->{conch}->{processor}->{count} =
		$device->{sysinfo}->{'CPU Physical Cores'};

	$device->{conch}->{processor}->{type} = $device->{sysinfo}->{'CPU Type'};

	return $device;
}

sub _product {
	my ($device) = @_;

	$device->{conch}->{product_name} = $device->{sysinfo}->{Product} || undef;

	return $device;
}

sub _sku {
	my ($device) = @_;

	# "SKU Number": "SKU=NotProvided;ModelName=Joyent-Compute-Platform-3301",
	# "SKU Number": "600-0032-001",
	my $sku = $device->{sysinfo}->{'SKU Number'};
	$sku =~ s/;.*$//;
	$sku =~ s/^SKU=//;
	
	$device->{conch}->{sku} = $sku || undef;

	return $device;
}

sub _system_uuid {
	my ($device) = @_;

	# Sysinfo:                 44454c4c-5400-1059-804a-b8c04f524432
	# SMBIOS UUID:             44454c4c-5400-1059-804a-b8c04f524432
	# UUID (Endian-corrected): 4c4c4544-0054-5910-804a-b8c04f524432

	$device->{conch}->{system_uuid} = $device->{sysinfo}->{UUID};

	return $device;
}

sub _hardware_family {
	my ($device) = @_;

	# "HW Family": "M12"
	$device->{conch}->{hardware_family} =
		$device->{sysinfo}->{'HW Family'} || undef;

	return $device;
}

sub _hardware_version {
	my ($device) = @_;

	# "HW Version": "001",
	$device->{conch}->{hardware_version} =
		$device->{sysinfo}->{'HW Version'} || undef;

	return $device;
}

sub _operating_system {
	my ($device) = @_;

	# SunOS, Linux
	$device->{conch}->{os}->{type}     = $device->{sysinfo}->{'System Type'};
	$device->{conch}->{os}->{version}  = $device->{sysinfo}->{'Live Image'};
	$device->{conch}->{os}->{hostname} = $device->{sysinfo}->{'Hostname'};

	return $device;
}

sub _manufacturer {
	my ($device) = @_;

	# "Manufacturer": "Joyent"
	$device->{conch}->{manufacturer} = $device->{sysinfo}->{Manufacturer};

	return $device;
}

sub _triton {
	my ($device) = @_;

	$device->{conch}->{triton}->{datacenter} =
		$device->{sysinfo}->{'Datacenter Name'} || undef;

	$device->{conch}->{triton}->{version} =
		$device->{sysinfo}->{'SDC Version'} || undef;

	$device->{conch}->{triton}->{admin_nic_tag} =
		$device->{sysinfo}->{'Admin NIC Tag'} || undef;

	$device->{conch}->{triton}->{setup} =
		$device->{sysinfo}->{'Setup'} || undef;

	$device->{conch}->{triton}->{zpool} =
		$device->{sysinfo}->{'Zpool'} || undef;

	$device->{conch}->{triton}->{agents} =
		$device->{sysinfo}->{'SDC Agents'} || undef;

	$device->{conch}->{triton}->{boot_parameters} =
		$device->{sysinfo}->{'Boot Parameters'} || undef;

	$device->{conch}->{triton}->{vm_capable} =
		$device->{sysinfo}->{'VM Capable'} || undef;

	$device->{conch}->{triton}->{bhyve_capable} =
		$device->{sysinfo}->{'Bhyve Capable'} || undef;

	$device->{conch}->{triton}->{bhyve_max_vcpus} =
		$device->{sysinfo}->{'Bhyve Max Vcpus'} || undef;

	return $device;
}

1;
