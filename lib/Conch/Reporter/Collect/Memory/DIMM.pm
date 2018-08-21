package Conch::Reporter::Collect::Memory::DIMM;

use strict;
use warnings;

sub collect {
	my ($device) = @_;

	my $hw_memory = $device->{hwgrok}->{memory};

	# We don't have a JEDEC map on SmartOS, so we're going to get a hex
	# value for the manuf. On Linux w/ dmidecode, we would get a string, like
	# "Samsung." We need a JEDEC mapper to translate it.
	# TODO: LP-42423274

	my %vendors = (
		'00CE00B300CE' => 'Samsung',
		'00CE063200CE' => 'Samsung',
	);

	my %field_map = (
		label => 'memory-locator',
		dimm => {
			manufacturer    => 'memory-manufacturer',
			'part-number'   => 'memory-part-number',
			'serial-number' => 'memory-serial-number',
			'type'          => 'memory-type',
			'size-in-bytes' => 'memory-size',
		},
	);

	my @conch_dimms;

	foreach my $slot (@{$hw_memory}) {
		my $conch_dimm = {};
		$conch_dimm->{'memory-locator'} = $slot->{label};
		foreach my $k (keys %{$slot->{dimm}}) {
			my $remap = $field_map{dimm}{$k} || $k;
			$conch_dimm->{$remap} = $slot->{dimm}->{$k};
		}

		my $manuf = $conch_dimm->{'memory-manufacturer'};
		if ($vendors{ $manuf }) {
			$conch_dimm->{'memory-manufacturer'} = $vendors{ $manuf };
		}

		# This is not particularly accurate, unfortunately. e.g., a DIMM
		# that shows 17179869184 bytes we want to represent as "16GB", but...
		my $b = $conch_dimm->{'memory-size'};
		$b = $b*1e-9;
		$b = sprintf("%.0f", $b);
		$conch_dimm->{'memory-size'} = $b;

		push @conch_dimms, $conch_dimm;
	}

	$device->{conch}{dimms} = \@conch_dimms;

	my $ram_total = `/usr/sbin/prtconf -m`;
	chomp $ram_total;
	$ram_total = $ram_total / 1024;
	$ram_total = sprintf("%.0f", $ram_total);

	$device->{conch}->{memory}->{total} = $ram_total;
	$device->{conch}->{memory}->{count} = scalar @conch_dimms;

	return $device;
}

1;
