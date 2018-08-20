package Conch::Reporter::Collect::System::SMBIOS;

use strict;
use warnings;

sub collect {
	my ($device) = @_;

	$device->{conch}->{bios_version} = _bios_version();

	return $device;
}

sub _bios_version {
	my $version = `smbios -t 0 | grep 'Version String' | sed -e 's/^.*: //'`;
	chomp $version;

	return $version;
}

1;
