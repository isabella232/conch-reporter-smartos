package Conch::Reporter::Collect::Memory;

use strict;
use warnings;

use Data::Printer;
use Parse::DMIDecode;

use Exporter 'import';
our @EXPORT = qw( dimms );

sub dimms {
  my ( $device ) = @_;

  # Initialize our total memory count to zero (GB)
  $device->{memory}{total} = 0;

  # Initialize our DIMM count to 0
  $device->{memory}{count} = 0;

  my @dimms = ();
  my $decoder = Parse::DMIDecode->new(nowarnings => 1);

  $decoder->probe;
  $decoder->parse(qx(/usr/sbin/dmidecode));

  for my $handle ($decoder->get_handles( group => "memory" )) {
    next if ($handle->dmitype != 17);

    my $dimm = {};

    for my $keyword ($handle->keywords) {
      next if ($keyword eq "memory-array-handle" ||
               $keyword eq "memory-error-information-handle");
  
      my $value = $handle->keyword($keyword);

      # normalize fields which offer no data to undef
      if ($value eq "No Module Installed" ||
          $value eq "Not Provided" ||
          $value eq "Unknown" ||
          $value eq "None" ||
          $value eq "NO DIMM") {
        $dimm->{$keyword} = undef;
      } else {
        # convert certain values to standardized units

        # memory-*-width are integers in bits
        if ($keyword =~ /^memory-(data-|total-)width$/) {
          $value =~ s/\s\S+$//g;
        }

        # clocks speeds are integers in MHz
        if ($keyword =~ /^memory-(configured-clock-)?speed$/) {
          $value =~ s/\s\S+$//g;
        }

        if ($keyword eq "memory-size") {
          # SMCI reports in GB.
          # Dell reports in MB.
          # We normalize values to GB.
          if ($value =~ /\sMB$/) {
            $value =~ s/\s+.*//;
            $value /= 1024; # convert MB to GB
          } elsif ($value =~ /\sGB$/) {
            $value =~ s/\s+.*//;
          }

          # Increment our total memory and DIMM counts
          $device->{memory}{total} += $value;
          $device->{memory}{count} += 1;
        }

        $dimm->{$keyword} = $value;
      }
    }

    push @dimms, $dimm;
  }

  # tack our array of DIMMs onto the report
  $device->{dimms} = \@dimms;

  return $device;
}

1;
