package Conch::Reporter::Collect::Disk::Inventory;

use strict;
use warnings;

use Data::Printer;
use JSON;

# XXX We want arrays instead of a hash.
# XXX In API, test if this is an array or hash so we can convert?
sub collect {
	my ($device) = @_;

	my $disks = $device->{hwgrok}->{"drive-bays"};

	my $drive_type = "SAS_HDD";

	if ($device->{diskinfo}->{removable}) {
		$drive_type = "USB_HDD";
	}

	if ($device->{diskinfo}->{ssd}) {
		$drive_type = "SAS_SSD";
	}

	p $device;

	my %conch_disks;

	foreach my $disk (@{$disks}) {
		my $serial = $disk->{disk}->{'serial-number'};
		$conch_disks{$serial} = {
			device     => $disk->{disk}->{model} || undef,
			temp       => $disk->{disk}->{sensors}[0]->{reading} || undef,
			vendor     => $disk->{disk}->{manufacturer} || undef,
			size       => $disk->{disk}->{'size-in-bytes'} || undef,
			model      => $disk->{disk}->{model} || undef,
			device     => $device->{diskinfo}{device} || undef,
			drive_type => $drive_type || undef,
			enclosure  => $device->{diskinfo}->{enclosure},
			slot       => $device->{diskinfo}->{slot},
			health     => $device->{diskinfo}->{fault} || undef,
			guid       => undef,
		};
	}

	$device->{conch}->{disk} = \%conch_disks;

	return $device;
}

sub _smartctl { ... }
sub _sas3ircu { ... }

1;
