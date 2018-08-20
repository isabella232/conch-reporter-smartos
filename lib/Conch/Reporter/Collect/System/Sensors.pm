package Conch::Reporter::Collect::System::Sensors;

use strict;
use warnings;

sub collect {
	my ($device) = @_;

	$device = _chassis_sensors($device);

	return $device;
}

sub _chassis_sensors {
	my ($device) = @_;

	foreach my $sensor (@{$device->{hwgrok}->{chassis}->{sensors}}) {
		if ($sensor->{name} eq "Inlet Temp") {
			$device->{conch}->{temp}->{inlet}       = $sensor->{reading};
			$device->{conch}->{temp}->{inlet_units} = $sensor->{units};

			$device->{conch}->{temp}->{inlet_upper_crit} =
				$sensor->{'threshold-upper-critical'};

			$device->{conch}->{temp}->{inlet_lower_warn} =
				$sensor->{'threshold-lower-non-critical'};

			$device->{conch}->{temp}->{inlet_lower_crit} =
				$sensor->{'threshold-lower-critical'};

		}

		if ($sensor->{name} eq "Exhaust Temp") {
			$device->{conch}->{temp}->{exhaust}       = $sensor->{reading};
			$device->{conch}->{temp}->{exhaust_units} = $sensor->{units};
		}

		if ($sensor->{name} eq "Pwr Consumption") {
			$device->{conch}->{power}->{usage}->{current}  = $sensor->{reading};
			$device->{conch}->{power}->{usage}->{units}    = $sensor->{units};
		}
	}

	return $device;
}

1;
