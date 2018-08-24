package Conch::Reporter::Collect::Disk::Smartctl;

use strict;
use warnings;

use Carp;
use Path::Tiny;
use IPC::Cmd qw[can_run run run_forked];
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);

sub collect {
	my ($device) = @_;

	$device->{smartctl} = _smartctl($device);

	return $device;

}

sub _smartctl {
	my ($device) = @_;

	my $smartctl = {};

	foreach my $disk (keys %{$device->{diskinfo}}) {
		# Skip removable
		next if $device->{diskinfo}->{$disk}->{removable};
		my $dev = _smartctl_disk($device->{diskinfo}->{$disk}->{device});
		$smartctl->{$disk}->{health}   = $dev->{health};
		$smartctl->{$disk}->{temp}     = $dev->{temp};
		$smartctl->{$disk}->{rotation} = $dev->{rotation};
	}

	return $smartctl;
}

# XXX Consume SMART config as well
# SMART support is:     Available - device has SMART capability.
# SMART support is:     Enabled
# Temperature Warning:  Enabled

# XXX If SMART is not enabled, the validator should blow up.

# XXX etc
# Current Drive Temperature:     28 C
# Drive Trip Temperature:        70 C
# Manufactured in week 42 of year 2016
# Specified cycle count over device lifetime:  0
# Accumulated start-stop cycles:  0
# Specified load-unload count over device lifetime:  0
# Accumulated load-unload cycles:  0
# defect list format 6 unknown
# Elements in grown defect list: 0

# XXX SSD:
# Percentage used endurance indicator: 0%

sub _smartctl_disk {
	my ($disk, $is_perc) = @_;

	my $smartctl_opts = "-a /dev/rdsk/" . $disk;

	if ($is_perc) {
		$smartctl_opts .= " -d megaraid,0";
	}

	# XXX Catching errors here would be good.
	my $cmd = "./bin/smartctl -d scsi -T permissive $smartctl_opts";
	my $buffer;
	scalar run(command => $cmd,
		verbose => 0,
		buffer  => \$buffer,
		timeout => 20);

	my $devstat = {};

	# Initialize health and temp to something the validator will catch.
	# Under normal circumstances, these will be filled in with hopefully OK
	# values. If that fails to happen for some reason, the validator will catch
	# these outrageous values and we'll know to investigate.
	$devstat->{health} = "UNKNOWN";
	$devstat->{temp} = 200;

	# We get temps from hwgrok. Might be interesting to see if they are
	# different.
	for ( split /^/, $buffer ) {
		# SSDs aren't really supported by smartctl. They spit out a new fun
		# format:
		# ID  ATTRIBUTE_NAME       FLAG   VALUE WORST THRESH TYPE     UPDATED WHEN_FAILED RAW_VALUE
		# 194 Temperature_Celsius  0x0022 100   100    000   Old_age  Always  -           27
		if ( $_ =~ /Temperature_Celsius/) {
			my @a = split(/\s+/,$_);
			$devstat->{temp} = $a[-1];
		}

		# Back to our regularly schedule programming...
		next unless $_ =~ /:/;
		my ( $k, $v ) = split(/:/, $_);
		chomp $k;
		chomp $v;
		$v =~ s/^\s+|\s+$//g;

		if ( $k =~ /Rotation Rate/ ) {
			$devstat->{rotation} = $v;
		}

		if ( $k =~ /Serial/ ) {
			$devstat->{serial_number} = $v;
		}

		if ( $k =~ /SMART Health Status|SMART overall-health self-assessment
					test result/ ) {
			if ($v eq "PASSED") {
				 $v = "OK";
			}
			$devstat->{health} = $v;
		}

		if ( $k =~ /Current Drive Temperature/ ) {
			$v =~ s/ C$//;
			$devstat->{temp} = $v;
		}
	}

	return $devstat;
}

1;
