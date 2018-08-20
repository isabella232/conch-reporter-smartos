package Conch::Reporter::Collect::System::Power;

use strict;
use warnings;

sub collect {
	my ($device) = @_;

	$device = _power_supplies($device);

	return $device;
}

sub _power_supplies {
	my ($device) = @_;

	my @supplies;
	foreach my $psu (@{$device->{hwgrok}->{'power-supplies'}}) {
		my $present = 0;
		if ($psu->{sensors}->[0]->{'state-description'} eq "PRESENT") {
			$present = 1;
		}

		$psu->{label} =~ s/PSU //;
		my $p = {
			psu          => $psu->{label},
			firmware     => $psu->{'firmware-revision'},
			leds         => $psu->{leds},
			manufacturer => $psu->{manufacturer},
			model        => $psu->{model},
			present      => $present,
			usage        => $psu->{sensors}->[1]->{reading},
			usage_units  => $psu->{sensors}->[1]->{units},
		};

		push @supplies, $p;
	}

	$device->{conch}->{power}->{psu} = \@supplies;

	return $device;
}

1;
