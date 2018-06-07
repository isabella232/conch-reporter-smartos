package Conch::Reporter::Collect::Environment;

use strict;
use warnings;

use Data::Printer;

use Exporter 'import';
our @EXPORT = qw( temperature );

# Dell:
# Inlet Temp       | 23 degrees C      | ok
# Exhaust Temp     | 41 degrees C      | ok
# Temp             | 41 degrees C      | ok
# Temp             | 52 degrees C      | ok
#
# SMCI:
# CPU1 Temp        | 38 degrees C      | ok
# CPU2 Temp        | 38 degrees C      | ok
# PCH Temp         | 32 degrees C      | ok
# System Temp      | 29 degrees C      | ok
# Peripheral Temp  | 33 degrees C      | ok
sub temperature {
  my ($device) = @_;

  my $ipmi_sensors = `/usr/bin/ipmitool sdr | grep Temp`;
  chomp $ipmi_sensors;

  for (split/^/,$ipmi_sensors) {
    chomp;
    my ($k, $v, $status) = split/\|/, $_;

    $v =~ s/ degrees C//;

    $k =~ s/^\s+|\s+$//g;
    $v =~ s/^\s+|\s+$//g;
    $status =~ s/^\s+|\s+$//g;

    # If a sensor is returning no data or is disabled by the BMC
    # we will return -274 as the temperature. It is safe to assume that
    # any valid temperature readings will never be colder than one
    # degree below absolute zero.
    if ( $v =~ /^no reading|^disabled/ ) {
      $v = -274;
    }

    if ( $k =~ /^Inlet Temp|^System Temp/ ) {
      $device->{temp}->{inlet} = $v;
    }

    if ( $k =~ /^Exhaust Temp|^Peripheral Temp/ ) {
      $device->{temp}->{exhaust} = $v;
    }

    if ( $k =~ /^CPU1 Temp/ ) {
      $device->{temp}->{cpu0} = $v;
    }

    if ( $k =~ /^CPU2 Temp/ ) {
      $device->{temp}->{cpu1} = $v;
    }
  }

  # Because Dell and my bad Perl skills.
  # Physical id 0:  +41.0 C  (high = +93.0 C, crit = +103.0 C)
  # Physical id 1:  +52.0 C  (high = +93.0 C, crit = +103.0 C)
  my $cpu_temp = `/usr/bin/sensors | grep Phys`;
  chomp $cpu_temp;

  for (split/^/,$cpu_temp) {
    $_ =~ s/ C.*$//;
    $_ =~ s/\+//;
    my ($cpu, $temp) = split(/:/, $_);
    chomp $cpu;
    chomp $temp;
    $temp =~ s/^\s+|\s+$//g;
    $temp =~ s/\..*$//;

    if ($cpu eq "Physical id 0") {
      $device->{temp}->{cpu0} = $temp;
    }

    if ($cpu eq "Physical id 1") {
      $device->{temp}->{cpu1} = $temp;
    }
  }

  return $device;
}

1;
