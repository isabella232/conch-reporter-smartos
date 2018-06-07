package Conch::Reporter::Collect::Disk;

use strict;
use warnings;

use Data::Printer;
use Tie::File;
use JSON qw( );

use Exporter 'import';
our @EXPORT = qw( disks smartctl sas3 perc lsusb boot_order fio );


sub disks {
  my ( $device ) = @_;

  my $is_perc = 0;
  my $output =
    `/bin/lsblk -Pnido KNAME,TRAN,SIZE,VENDOR,MODEL,REV,HCTL > /tmp/lsblk.out`;

  open(FILE, "/tmp/lsblk.out") or die "Could not read file: $!";
  while(<FILE>) {
    chomp;

    # Expected output format with lsblk's -P option:
    # KNAME="sda" TRAN="" SIZE="7.3T" VENDOR="HGST    " MODEL="HUH721008AL4200 "

    my $disk   = $1 if /KNAME="(.*?)"/;
    my $tran   = $1 if /TRAN="(.*?)"/;
    my $size   = $1 if /SIZE="(.*?)"/;
    my $vendor = $1 if /VENDOR="(.*?)"/;
    my $model  = $1 if /MODEL="(.*?)"/;
    my $rev    = $1 if /REV="(.*?)"/;
    my $hctl   = $1 if /HCTL="(.*?)"/;

    # These can contain trailing spaces.
    $vendor =~ s/\s+$//g;
    $model =~ s/\s+$//g;

    # lsblk can't ascertain the transport of drives behind a RAID card
    # such as a Dell PERC/LSI MegaRAID.
    $tran = "unknown" if ($tran eq '');

    # If this is a Dell PERC/MegaRAID device, we will need to hint
    # this to smartctl() later on
    if ($vendor eq "DELL" && $model =~ /^PERC/) {
      $is_perc = 1;
    }

    my $devstat;

    if ($tran eq "usb") {
      $devstat = lsusb();
    } else {
      $devstat = smartctl($disk, $is_perc);
    }

    if ($size =~ /T/) {
      $size =~ s/T.*$//;
      $size = $size*1000000;
    }

    if ($size =~ /G/) {
      $size =~ s/G.*$//;
      $size = $size*1000;
    }

    unless (defined $devstat->{serial_number}) {
      warn "Could not get serial number for $disk!";
      next;
    }

    my $sn = $devstat->{serial_number};

    $device->{disks}{$sn}{device} = $disk;
    $device->{disks}{$sn}{health} = $devstat->{health} if defined $devstat->{health};
    $device->{disks}{$sn}{temp}   = $devstat->{temp} if defined $devstat->{temp};

    # We might get these from lsusb, or it might be defined from sas3 already.
    unless ( $device->{disks}{$sn}{hba} ) {
      $device->{disks}{$sn}{hba}    = $devstat->{hba} || 0;
    }

    $device->{disks}{$sn}{slot}   = $devstat->{slot} if defined $devstat->{slot};

    $device->{disks}{$sn}{transport} = $tran;
    $device->{disks}{$sn}{size}      = $size;
    $device->{disks}{$sn}{vendor}    = $vendor;
    $device->{disks}{$sn}{model}     = $model;
    $device->{disks}{$sn}{firmware}  = $rev;
    $device->{disks}{$sn}{hctl}      = $hctl;

    # Fill in some missing info if this is a PERC RAID LUN and not an
    # actual disk.
    if ($is_perc) {
      $device->{disks}{$sn}{transport} = "sas";
      $device->{disks}{$sn}{drive_type} = "SAS_HDD";
      $device->{disks}{$sn}{slot} = 63;
      $device->{disks}{$sn}{enclosure} = 0;
    }
  }

  close FILE;

  return $device;
}


sub smartctl {
  my $disk = shift;
  my $is_perc = shift;

  my $smartctl_opts = "-a /dev/" . $disk;

  if ($is_perc) {
    $smartctl_opts .= " -d megaraid,0";
  }

  my $smartctl = `/usr/sbin/smartctl $smartctl_opts`;
  chomp $smartctl;

  my $devstat = {};

  # Initialize health and temp to something the validator will catch.
  # Under normal circumstances, these will be filled in with hopefully OK
  # values. If that fails to happen for some reason, the validator will catch
  # these outrageous values and we'll know to investigate.
  $devstat->{health} = "UNKNOWN";
  $devstat->{temp} = 200;

  for ( split /^/, $smartctl ) {

    # SSDs aren't really supported by smartctl. They spit out a new fun format.
    # ID# ATTRIBUTE_NAME          FLAG     VALUE WORST THRESH TYPE      UPDATED WHEN_FAILED RAW_VALUE
    # 194 Temperature_Celsius     0x0022   100   100   000    Old_age   Always # -       27
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

    if ( $k =~ /SMART Health Status|SMART overall-health self-assessment test result/ ) {
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

sub process_sas3_line {
  my ($uuid, $lines, $line) = @_;
  return unless $line =~ /:/;
  chomp $line;
  my ($k, $v) = split(/:/, $line);
  $v =~ s/^\s+|\s+$//g;
  $k =~ s/^\s+|\s+$//g;
  $lines->{$uuid}{$k} = $v;
}

sub sas3 {
  my ( $device ) = @_;

  my $ctlr_cnt = 0;

  #
  # Count the number of SAS HBAs we have
  # As inelegant as it is, we must scrape the output of
  # sas3ircu to get this info. We key in on the '-----` which
  # preceded each described HBA.
  #
  my $sas3list = `/opt/local/bin/sas3ircu LIST > /tmp/sas3list.out`;

  open(SAS3LIST, "/tmp/sas3list.out");

  my %lines;

  while(<SAS3LIST>) {
    $ctlr_cnt++ if ($_ =~ /^ ----- /);
  }

  close SAS3LIST;

  #
  # Iterate over each HBA and catalog its devices.
  # Again, we scrape the output of sas3ircu to get this info.
  #
  for (my $i = 0; $i < $ctlr_cnt; $i++) {
    my $outfile = "/tmp/sas3-" . $i . ".out";
    my $sas3 = `/opt/local/bin/sas3ircu $i DISPLAY > $outfile`;

    my %c_lines;
    my %d_lines;

    # Generate per-HBA UUID
    my $uuidgen = `uuid`;
    chomp $uuidgen;
    my $hba_uuid = $uuidgen;

    open(FILE, $outfile);

    while(<FILE>) {
      # Trim whitespace off the beginning and end of lines
      s/^\s+|\s+$//g;

      # Pick out HBA info
      if (/^Controller information$/) {
        while(<FILE>) {
          # Trim whitespace off the beginning and end of lines
          s/^\s+|\s+$//g;

          # If we've reached this line, we've exited the controller section
          last if (/^IR Volume information$/);

          # Collect desired controller info
          if (/^Controller type\s{2}/ ||
              /^BIOS version\s{2}/ ||
              /^Firmware version\s{2}/ ||
              /^Slot\s{2}/ ||
              /^Segment\s{2}/ ||
              /^Bus\s{2}/ ||
              /^Device\s{2}/) {
            process_sas3_line($hba_uuid, \%c_lines, $_);
          }
        }
      }

      # Pick out per-hard drive info
      if (/^Device is a Hard disk$/) {
        # Generate per-disk UUID
        my $uuidgen = `uuid`;
        chomp $uuidgen;
        my $uuid = $uuidgen;

        while(<FILE>) {
          # A blank line means we are done with this disk
          if (/^$/) {
            last;
          } else {
            # Trim whitespace off the beginning and end of lines
            s/^\s+|\s+$//g;
            process_sas3_line($uuid, \%d_lines, $_);
          }
        }
      }
    }

    close FILE;

    foreach my $key (keys %d_lines) {
      my $sn                             = $d_lines{$key}{'Serial No'};
      $device->{disks}{$sn}{slot}        = $d_lines{$key}{'Slot #'};
      $device->{disks}{$sn}{drive_type}  = $d_lines{$key}{'Drive Type'};
      $device->{disks}{$sn}{guid}        = $d_lines{$key}{'GUID'};
      $device->{disks}{$sn}{enclosure}   = $d_lines{$key}{'Enclosure #'};
      $device->{disks}{$sn}{hba}         = $i;
    }

    foreach my $key (keys %c_lines) {
      $device->{hba}{$i}{type}           = $c_lines{$key}{'Controller type'};
      $device->{hba}{$i}{bios_ver}       = $c_lines{$key}{'BIOS version'};
      $device->{hba}{$i}{firmware_ver}   = $c_lines{$key}{'Firmware version'};
      $device->{hba}{$i}{slot}           = $c_lines{$key}{'Slot'};
      $device->{hba}{$i}{segment}        = $c_lines{$key}{'Segment'};
      $device->{hba}{$i}{bus}            = $c_lines{$key}{'Bus'};
      $device->{hba}{$i}{device}         = $c_lines{$key}{'Device'};
    }
  }

  return $device;
}

sub perc {
  my ( $device ) = @_;
  my $devstat = {};

  # Get a list of PERC controllers
  my $raidcfg_ctrl=
    `/opt/dell/toolkit/bin/raidcfg -ctrl > /tmp/perc_raidcfg_ctrl.out`;

  # exit if raidcfg did not find a PERC
  return $device if ($? != 0);

  my $ctrl_id = undef;
  my @lines;
  tie @lines, 'Tie::File', "/tmp/perc_raidcfg_ctrl.out";

  foreach (@lines) {
    next if ! /\w:\s/;

    my ($k, $v) = split(/: /);
    $k =~ s/^\s+|\s+$//g;
    $v =~ s/^\s+|\s+$//g;

    if ($k eq "Controller_ID/Slot_ID") {
      $ctrl_id = $v;
    }

    if ($k eq "Controller_Name") {
      $devstat->{$ctrl_id}->{type} = $v;
    }

    if ($k eq "Firmware Version") {
      $devstat->{$ctrl_id}->{firmware} = $v;
    }
  }

  untie @lines;

  foreach my $ctrl (keys %{$devstat}) {
    my $outfile = "/tmp/perc_raidcfg_adisk-" . $ctrl . ".out";
    my $raidcfg_adisk = `/opt/dell/toolkit/bin/raidcfg -ad -c=$ctrl > $outfile`;

    return $device if ($? != 0);

    my $disk = -1;
    my @lines;
    tie @lines, 'Tie::File', $outfile;

    foreach (@lines) {
      $disk++ if /\*{16} Physical Drive/;
      next if ! /\w:\s\s/;

      my ($k, $v) = split(/:\s\s/);
      $k =~ s/^\s+|\s+$//g;
      $v =~ s/^\s+|\s+$//g;

      if ($k eq "Location") {
        # Annoyingly, raidcfg thinks LUNs start at 1, where the rest
        # of Linux starts at 0. We are going to normalize the L part
        # of C:T:L to Linux
        my ($c, $t, $l) = split(/:/, $v);
        $l = int($l) - 1;
        my $hctl = "0:" . $c . ":" . $t . ":" . $l;
        $devstat->{$ctrl}{'disks'}{$disk}{hctl} = $hctl;
      }

      if ($k eq "Protocol") {
        $devstat->{$ctrl}{'disks'}{$disk}{protocol} = $v;
      }

      if ($k eq "Media") {
        $devstat->{$ctrl}{'disks'}{$disk}{media} = $v;
      }

      if ($k eq "Model") {
        $devstat->{$ctrl}{'disks'}{$disk}{model} = $v;
      }
    }

    untie @lines;
  }

  # Now match up raidcfg's output with what we have stored in the global
  # $devices hash, which has disk info populated by lsblk data
  for my $perc (keys %$devstat) {
    for my $pdisk (keys %{$devstat->{$perc}->{disks}}) {
      for my $disk (keys %{$device->{disks}}) {
        my $disk_hctl = $device->{disks}->{$disk}->{hctl};
        my $pdisk_hctl = $devstat->{$perc}->{disks}->{$pdisk}->{hctl};
        if ($disk_hctl eq $pdisk_hctl) {
            $device->{disks}{$disk}{transport} =
              lc($devstat->{$perc}->{disks}->{$pdisk}->{protocol});

            $device->{disks}{$disk}{drive_type} =
              $devstat->{$perc}->{disks}->{$pdisk}->{protocol} .
              "_" . $devstat->{$perc}->{disks}->{$pdisk}->{media};

            $device->{disks}{$disk}{slot} = $pdisk;
            $device->{disks}{$disk}{enclosure} = 0;
        }
      }
    }
  }

  return $device;
}

# This is terrible, even for me.
sub lsusb {
  my $devstat = {};

  # XXX This needs to get updated whenever we change USB drives.
  my $device_id = `/usr/bin/lsusb | grep -e Flash -e Kingston`;
  $device_id =~ s/^.*Bus //;
  $device_id =~ s/:.*$//;
  $device_id =~ s/ Device /:/;

  chomp $device_id;

  my $lsusb = `/usr/bin/lsusb -v -s $device_id | grep iSerial`;
  chomp $lsusb;

  my @line = split(/\s+/,$lsusb);
  my $sn = $line[-1];

  my ($hba,$slot) = split(/:/,$device_id);

  $devstat->{serial_number} = $sn;
  $devstat->{hba}  = $hba;
  $devstat->{slot} = $slot;

  return $devstat;
}

# XXX Needs to be implemented
# Identity function
sub boot_order {
  return shift;
}

# Collect fio json output from the burnin process
# Insert the serial number of the disk into the results
sub fio {
  my $fio_report = shift;
  my $i = 0;

  return undef if ! -f $fio_report;

  my $json_text = do {
    open(my $json_fh, "<:encoding(UTF-8)", $fio_report) ||
      die("Cannot open \$fio_report\": $!\n");

    # slurp
    local $/;
    <$json_fh>
  };

  my $json = JSON->new;
  my $data = $json->decode($json_text);

  my @disks = @{ $data->{'disk_util'} };

  foreach my $disk (@disks) {
    my $dev = $disk->{'name'};
    my $sn;

    # REEEEEE
    # should be able to just cat a file in /sys/block/$dev for this
    # because we can't, we scrape smartctl output for it.
    chomp(my @out = `/usr/sbin/smartctl -a /dev/$dev`);
    my @lines = grep { /^Serial/ } @out;

    # should be only one line, and the 3rd word in it
    # "Serial number:        7JHJRAUG"
    foreach my $line (@lines) {
      $sn = ($line =~ m/\w+/g)[2];
    }

    # insert this disk's serial number and move to the next one
    $data->{'disk_util'}[$i]{'serial'} = $sn;
    $i++;
  }

  return $data;
}

1;
