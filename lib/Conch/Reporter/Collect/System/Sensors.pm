package Conch::Reporter::Collect::System::Sensors;

use strict;
use warnings;

use IPC::Cmd qw[can_run run run_forked];

sub collect {
	my ($device) = @_;

	$device = _chassis_sensors($device);
	$device = _ipmi_sensors($device);

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

sub _ipmi_sensors {
	my ($device) = @_;

	# Temp             | 38.000     | degrees C  | ok    | na        | 3.000 | 8.000     | 98.000    | 103.000   | na
	my $cmd = "/usr/sbin/ipmitool sensor list | grep ^Temp";
	my( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) =
		run( command => $cmd, verbose => 0, timeout => 30 );

	my $count = 0;
	my @lines = split(/\n/, $stdout_buf->[0]);
	foreach my $ln (@lines) {
		chomp $ln;
		my @line = split(/\|/, $ln);
		my $cpu = "cpu$count";
		my $temp = $line[1];
		$temp =~ s/^\s+|\s+$//g;
		$temp = sprintf("%.0f", $temp);
		$device->{conch}->{temp}->{$cpu} = $temp;
		$count++;
	}

	return $device;
}

1;
