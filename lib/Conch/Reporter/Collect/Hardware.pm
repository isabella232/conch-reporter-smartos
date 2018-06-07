package Conch::Reporter::Collect::Hardware;

use strict;
use warnings;

use Data::Printer;

use Exporter 'import';
our @EXPORT = qw( core_hardware_components
                  hardware_identifiers
                  uptime_since );

sub core_hardware_components {
  my ( $device ) = @_;

  # lshw JSON and XML output is broken in awesome ways, so we resort to this.
  my $output = `/usr/bin/lshw -quiet -short > /tmp/lshw.out`;

  open(FILE, "/tmp/lshw.out") or die "Could not read file: $!";

  while(<FILE>) {
    chomp;
    my @line = split(/\s+/,$_);

    # Get network info.
    if ( $_ =~ /network/ ) {
      my $product = join(" ", splice(@line, 3, $#line));
      my $iface = $line[1];
      if ( $iface =~ /^eth/ && $product ) {
        $device->{interfaces}{$iface}{product} = $product;

        # XXX Don't start with me.
        $device->{interfaces}{$iface}{vendor} = "Intel";
      }
    }
  }

  close FILE;

  return $device;
}

# XXX This should be broken into a few different subroutines
sub hardware_identifiers {
  my ($device, $ohai ) = @_;

  my $serial_number = $ohai->{dmi}->{system}->{serial_number};

  $device->{serial_number} = $serial_number;
  $device->{product_name}  = $ohai->{dmi}->{system}->{product_name};
  $device->{system_uuid}   = $ohai->{dmi}->{system}->{uuid};
  $device->{state}         = "ONLINE";
  $device->{health}        = "PASS";

  # The Dell R730xd do not have any product or vendor string programmed
  # at the factory for some reason, so it shows up as blank. If it is blank
  # we are going to assume it is a R730xd, aka JCP 3211.
  if ($device->{product_name} eq '') {
    $device->{product_name} = "Joyent-Compute-Platform-3211";
  }

  my $thermal_state = $ohai->{dmi}->{chassis}->{thermal_state};
  my $psu_state     = $ohai->{dmi}->{chassis}->{power_supply_state};

  if ($thermal_state ne "Safe") {
    warn "$thermal_state";
    $device->{health} = "FAIL";
  }

  if ($psu_state ne "Safe") {
    warn "$psu_state";
    $device->{health} = "FAIL";
  }

  $device->{bios_version} = $ohai->{dmi}->{bios}->{version};

  return $device;
}

sub uptime_since {
  my $device = shift || {};
  chomp(my $uptime = `/usr/bin/uptime --since`);
  chomp(my $fmt_uptime = `/bin/date -d "$uptime" --rfc-3339=seconds`);
  $device->{uptime_since} = $fmt_uptime;
  return $device;
}

1;
