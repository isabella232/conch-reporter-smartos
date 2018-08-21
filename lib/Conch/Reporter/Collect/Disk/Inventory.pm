package Conch::Reporter::Collect::Disk::Inventory;

use strict;
use warnings;

use Conch::Reporter::Collect::Disk::Smartctl;

# XXX We want arrays instead of a hash.
# XXX In API, test if this is an array or hash so we can convert?
sub collect {
	my ($device) = @_;

	my $hw_disks = $device->{hwgrok}->{"drive-bays"};
	my $diskinfo = $device->{diskinfo};

	my %conch_disks;

	# Note: hwgrok will not include USB drives, and there is a workaround
	# in the Diskinfo collector for USB serial numbers. So we loop over
	# diskinfo disks, and then populate data more from hwgrok.

	foreach my $serial (keys %{$diskinfo}) {
		my $drive_type = "SAS_HDD";

		if ($diskinfo->{$serial}->{removable}) {
			$drive_type = "USB_HDD";
		}

		if ($diskinfo->{$serial}->{ssd}) {
			$drive_type = "SAS_SSD";
		}

		$conch_disks{$serial} = $diskinfo->{$serial};
		$conch_disks{$serial}->{drive_type} = $drive_type;

		$conch_disks{$serial}->{health} =
			$device->{smartctl}->{$serial}->{health} || undef;
		$conch_disks{$serial}->{smart_temp} =
			$device->{smartctl}->{$serial}->{temp} || undef;
		$conch_disks{$serial}->{rotation} =
			$device->{smartctl}->{$serial}->{rotation} || undef;
		
	}

	foreach my $disk (@{$hw_disks}) {
		my $serial = $disk->{disk}->{'serial-number'};
		$conch_disks{$serial}->{guid}     = undef;
		$conch_disks{$serial}->{temp} = 
			$disk->{disk}->{sensors}[0]->{reading} || undef,
		$conch_disks{$serial}->{firmware} =
			$disk->{disk}->{'firmware-revision'};

		# 0: LOCATE, 1: SERVICE, 2: OK2RM
		# XXX This has not been tested. There are two leds objects.
		#$conch_disks{$serial}->{leds} = $disk->{leds};
	};

	$device->{conch}->{disks} = \%conch_disks;

	# XXX We would prefer to operate on arrayrefs everywhere.
	# XXX We could also have the API check if the ref we submit until all
	# XXX reporters are converted to arrayrefs.
	my @disks;
	foreach my $serial (keys %{$device->{conch}->{disks}}) {
		my $disk = $device->{conch}->{disks}->{$serial};
		$disk->{serial} = $serial;
		push @disks, $disk;
	}

	$device->{conch}->{disks_arr} = \@disks;

	return $device;
}

1;
