package Conch::Reporter::Collect::Memory::DIMM;

use strict;
use warnings;

use Data::Printer;
use JSON;

sub collect {
	my ($device) = @_;

	my $hw_memory = $device->{hwgrok}->{memory};

	# We don't have a JEDEC map on SmartOS, so we're going to get a hex
	# value for the manuf. On Linux w/ dmidecode, we would get a string, like
	# "Samsung." We need a JEDEC mapper to translate it.
	# TODO: LP-42423274

	my %vendors = (
		'00CE00B300CE' => 'Samsung',
	);

	my %field_map = (
		label => 'memory-locator',
		dimm => {
			manufacturer    => 'memory-manufacturer',
			'part-number'   => 'memory-manufacturer',
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
			if ($field_map{$k}) {
				my $remap = $field_map{$k};
				$conch_dimm->{$remap} = $slot->{dimm}->{$k};
			} else {
				$conch_dimm->{$k} = $slot->{dimm}->{$k};
			}
		}

		# XXX Convert size to GB
		push @conch_dimms, $conch_dimm;
	}

	p @conch_dimms;

	$device->{conch}{dimms} = \@conch_dimms;

	return $device;
}

1;
