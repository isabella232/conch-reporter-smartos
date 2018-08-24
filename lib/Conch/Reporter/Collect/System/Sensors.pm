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
			$device->{conch}->{temp}->{inlet}       = $sensor->{reading} || undef;
			$device->{conch}->{temp}->{inlet_units} = $sensor->{units};

			$device->{conch}->{temp}->{inlet_upper_crit} =
				$sensor->{'threshold-upper-critical'};

			$device->{conch}->{temp}->{inlet_lower_warn} =
				$sensor->{'threshold-lower-non-critical'};

			$device->{conch}->{temp}->{inlet_lower_crit} =
				$sensor->{'threshold-lower-critical'};

		}

		if ($sensor->{name} eq "Exhaust Temp") {
			$device->{conch}->{temp}->{exhaust}       = $sensor->{reading} || undef;
			$device->{conch}->{temp}->{exhaust_units} = $sensor->{units};
		}

		if ($sensor->{name} eq "Pwr Consumption") {
			$device->{conch}->{power}->{usage}->{current}  = $sensor->{reading} || undef;
			$device->{conch}->{power}->{usage}->{units}    = $sensor->{units};
		}
	}

	return $device;
}

sub _ipmi_sensors {
	my ($device) = @_;

	# XXX SMCI
	# CPU1 Temp        | 42.000     | degrees C  | ok    | 0.000     | 0.000 | 0.000     | 98.000    | 103.000   | 103.000   
    # CPU2 Temp        | 43.000     | degrees C  | ok    | 0.000     | 0.000     | 0.000     | 98.000    | 103.000   | 103.000   
    # System Temp      | 33.000     | degrees C  | ok    | -9.000    | -7.000    | -5.000    | 80.000    | 85.000    | 90.000

	# XXX Dell
	# Inlet Temp       | 26.000     | degrees C  | ok    | na        | -7.000    | 3.000     | 42.000    | 47.000    | na        
	# Exhaust Temp     | 33.000     | degrees C  | ok    | na        | 0.000     | 0.000     | 70.000    | 75.000    | na        
	# Temp             | 38.000     | degrees C  | ok    | na        | 3.000     | 8.000     | 98.000    | 103.000   | na        
	# Temp             | 42.000     | degrees C  | ok    | na        | 3.000     | 8.000     | 98.000    | 103.000   | na        

	my $cmd = "/usr/sbin/ipmitool sensor list";
	my( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) =
		run( command => $cmd, verbose => 0, timeout => 30 );

	my $count = 0;
	my @lines = split(/\n/, $stdout_buf->[0]);
	foreach my $ln (@lines) {
		next unless $ln =~ /Temp/;
		chomp $ln;
		my @line = split(/\|/, $ln);
		my $key = $line[0];
		$key =~ s/^\s+|\s+$//g;
		my $value = $line[1];
		$value =~ s/^\s+|\s+$//g;
		next unless $value =~ m/\d+/;
		$value = sprintf("%.0f", $value);

		if ($key =~ m/^System|^Inlet|^Exhaust/) {
			$key =~ s/ .*$//;
			if ($key =~ /System/i) {
				$device->{conch}->{temp}->{inlet}   = $value;
				$device->{conch}->{temp}->{exhaust} = $value;
			}
			$device->{conch}->{temp}->{lc($key)} = $value;
		}

		if ($key =~ m/^Temp|^CPU/) {
			my $cpu = "cpu$count";
			$device->{conch}->{temp}->{$cpu} = $value;
			$count++;
		}
	}

	return $device;
}

1;
