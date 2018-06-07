package Conch::Reporter::Collect::CPU;

use strict;
use warnings;

use Linux::Cpuinfo;

use Exporter 'import';
our @EXPORT = qw( cpus );

sub cpus {
  my ( $device ) = @_;

  my $cpuinfo = Linux::Cpuinfo->new();

  # Initialize an array to store a hash for each CPU core
  my @cpus = ();

  # Build a per-CPU (core) hash of properties and push each
  # onto the @cpus array.
  foreach my $cp ($cpuinfo->cpus()) {
    my $cpu = {};

    $cpu->{model_name} = $cp->model_name();
    $cpu->{model_family} = $cp->cpu_family();
    $cpu->{model_id} = $cp->model();
    $cpu->{model_stepping} = $cp->stepping();
    $cpu->{clock} = $cp->cpu_mhz();
    $cpu->{microcode} = $cp->microcode();
    $cpu->{socket_id} = $cp->physical_id();
    $cpu->{core_id} = $cp->core_id();
    $cpu->{flags} = $cp->flags();

    push @cpus, $cpu;
  }

  # Build an array of unique 'socket_id's so that we may count them
  # in order to provide a count of CPU sockets that are populated.
  my @sockets;
  my %seen;
  foreach my $cpu (@cpus) {
    if (! $seen{$cpu->{socket_id}}) {
      push @sockets, $cpu->{socket_id};
      $seen{$cpu->{socket_id}} = 1;
    }
  }

  # XXX Legacy: the validator should instead use the new cpus array
  # to derive this information.
  $device->{processor}{count} = @sockets;
  $device->{processor}{type} = $cpuinfo->cpu->model_name(0);

  # Add our array of CPUs to the device report
  $device->{cpus} = \@cpus;

  return $device;
}

1;
