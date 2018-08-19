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

	my %conch_disks = map {
		my $serial = $_->{disk}->{'serial-number'};
		# XXX type should be: SAS_HDD, SAS_SSD, SATA_HDD
		# XXX If diskinfo is empty, call Disk::Diskinfo::collect directly.
		my $type = $device->{diskinfo}->{$serial}[6] =~ /S/ ? "SSD" : "SCSI";
		$serial=> {
			device     => $_->{disk}->{model},
			temp       => $_->{disk}->{sensors}[0]->{reading},
			slot       => $_->{label} =~ s/Drive Slot\s+(:?0+(?=.))*//r,
			vendor     => $_->{disk}->{manufacturer},
			size       => $_->{disk}->{'size-in-bytes'},
			model      => $_->{disk}->{model},
			device     => $device->{diskinfo}->{$serial}[1],
			drive_type => $type,
			enclosure  => undef,
			health     => undef,
			guid       => undef
		}
	} @{$disks};

	$device->{conch}->{disk} = \%conch_disks;

	return $device;
}

sub _smartctl { ... }
sub _sas3ircu { ... }

1;
