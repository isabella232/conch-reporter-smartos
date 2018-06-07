package Conch::Reporter::Collect::Network;

use strict;
use warnings;

use Data::Printer;
use Hash::Merge qw(merge);

use Exporter 'import';
our @EXPORT = qw( network_interfaces ipmi_net switch_ports );

sub network_interfaces {
  my ( $device, $ohai ) = @_;

  foreach my $iface (keys %{$ohai->{network}->{interfaces}}) {
    next unless $iface =~ /^eth/;

    my $mac;
    my $ipaddr;

    foreach my $addr (keys %{$ohai->{network}->{interfaces}->{$iface}->{addresses}}) {
      if ( $ohai->{network}->{interfaces}->{$iface}->{addresses}->{$addr}->{family} eq "lladdr" ) {
        $mac = $addr;
      }

      # This only supports one IP, which is fine for our use case.
      if ( $ohai->{network}->{interfaces}->{$iface}->{addresses}->{$addr}->{family} eq "inet" ) {
        $ipaddr = $addr;
      }
    }

    $device->{interfaces}{$iface}{ipaddr} = $ipaddr;
    $device->{interfaces}{$iface}{mac}    = $mac;
    $device->{interfaces}{$iface}{state}  = $ohai->{network}->{interfaces}->{$iface}->{state};
    $device->{interfaces}{$iface}{mtu}    = $ohai->{network}->{interfaces}->{$iface}->{mtu};

  }

  return $device;
}

sub switch_ports {
  my $device = shift || {};

  my $output = `/usr/sbin/lldpctl -f keyvalue > /tmp/lldpctl.out`;
  open(FILE, "/tmp/lldpctl.out") or die "Could not read file: $!";
  my $lldp = {};

  # Extract key/values and build up a nested hashref to reflect the key path.
  # Lines in the file look like 'lldp.eth1.chassis.name=Dell'.
  while(<FILE>) {
    chomp;
    my ($k, $v) = split/=/;
    my @elems = split /\./, $k;
    my $last_key = pop @elems;
    my $hash = { $last_key => $v };
    for my $e (reverse @elems) {
      $hash = { $e => $hash}
    }
    $lldp = merge($hash, $lldp);
  }
  # Pop off the first unnecesary hash
  $lldp = $lldp->{lldp};

  my $switch_port;
  for my $iface (keys %{$lldp}) {
    my $switch_port = $lldp->{$iface}->{port}->{ifname};
    $switch_port =~ s/TenGigabitEthernet //;

    $device->{interfaces}{$iface}{peer_port}   = $switch_port;
    $device->{interfaces}{$iface}{peer_switch} = $lldp->{$iface}->{chassis}->{name};
    $device->{interfaces}{$iface}{peer_mac}    = $lldp->{$iface}->{chassis}->{mac};
    $device->{interfaces}{$iface}{peer_text}   =
      $lldp->{$iface}->{chassis}->{name} . " " . $lldp->{$iface}->{port}->{ifname};
  }

  return $device;
}

sub ipmi_net {
  my ($device) = @_;
  my $output = `/usr/bin/ipmitool lan print 1 > /tmp/ipmi_net.out`;

  open(FILE, "/tmp/ipmi_net.out") or die "Could not read file: $!";

  while(<FILE>) {
    chomp;
    my ($k, $v) = split(/ : /,$_);
    $k =~ s/^\s+|\s+$//g;
    $v =~ s/^\s+|\s+$//g;

    if ( $k eq "IP Address" ) {
      $device->{interfaces}{ipmi1}{ipaddr} = $v;
    }

    if ( $k eq "MAC Address" ) {
      $device->{interfaces}{ipmi1}{mac}    = $v;
    }

    # XXX Could make this smarter by detecting Dell vs SMCI. Or not.
    # racadm getniccfg can tell you if the DRAC link is up, for instance.
    $device->{interfaces}{ipmi1}{product} = "OOB";
    $device->{interfaces}{ipmi1}{vendor}  = "Intel";
  }

  close FILE;

  return $device;
}

1;
