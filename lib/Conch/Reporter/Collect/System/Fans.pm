package Conch::Reporter::Collect::System::Fans;

use strict;
use warnings;

use Data::Printer;

sub collect {
	my ($device) = @_;

	$device = _fans($device);

	return $device;
}

sub _fans {
	my ($device) = @_;

	my @fans;
	foreach my $fan (@{$device->{hwgrok}->{'fans'}}) {

		$fan->{label} =~ s/FAN //;
		my $f = {
			fan          => $fan->{label},
			speed        => $fan->{sensors}->[0]->{reading},
			speed_units  => $fan->{sensors}->[0]->{units},
		};

		push @fans, $f;
	}

	$device->{conch}->{fans} = \@fans;

	return $device;
}

1;
