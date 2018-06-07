package Conch::Reporter;

use strict;
use warnings;

use JSON;
use Data::Printer;
use HTTP::Tiny;

use Conch::Reporter::Collect::Disk;
use Conch::Reporter::Collect::Environment;
use Conch::Reporter::Collect::Hardware;
use Conch::Reporter::Collect::Memory;
use Conch::Reporter::Collect::CPU;
use Conch::Reporter::Collect::Network;
use Conch::Reporter::Collect::Ohai 'ohai';

use Exporter 'import';
our @EXPORT = qw( collect_report publish_report );

sub collect_report {
  my $device = {};
  my $ohai = ohai();

  # I use short names to prepare for an eventual transition to role-based dispatch
  $device = core_hardware_components($device);
  $device = disks($device);

  if (find_pci_dev("Symbios Logic MegaRAID")) {
    $device = perc($device);
  }

  if (find_pci_dev("Fusion-MPT SAS")) {
    $device = sas3($device);
  }

  $device = boot_order($device);
  $device = cpus($device);
  $device = dimms($device);
  $device = network_interfaces($device, $ohai);
  $device = ipmi_net($device);
  $device = switch_ports($device);
  $device = hardware_identifiers($device, $ohai);
  $device = temperature($device);
  $device = uptime_since($device);
  return $device
}

sub find_pci_dev {
  my $dev_string = shift;

  my $lspci = `/usr/bin/lspci`;

  if ($lspci =~ /$dev_string/) {
    return 1;
  } else {
    return undef;
  }
}

sub publish_report {
  my $device = shift;
  my $device_id = $device->{serial_number};
  my $relay_host_url =
    $ENV{'RELAY_HOST_URL'} || 'http://conch-relay.joyent.us/report';

  my $report_uuid = `uuid`;
  chomp $report_uuid;

  $device->{report_id} = $report_uuid;

  my $response = HTTP::Tiny->new->post(
    #"$relay_host_url" => {
    "http://conch-relay.joyent.us/report" => {
      content => to_json($device),
      headers => {
        "Content-Type" => "application/json",
      },
    },
  );

  print $response->{content};
}

1;
