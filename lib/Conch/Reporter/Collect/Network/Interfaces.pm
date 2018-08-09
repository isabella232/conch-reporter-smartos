package Conch::Reporter::Collect::Network::Interfaces;

use strict;
use warnings;

sub interfaces {
	my ( $device) = @_;

# [root@headnode (us-east-1) /var/tmp/dc-standup]# dladm show-phys -m
# LINK         SLOT     ADDRESS            INUSE CLIENT
# igb0         primary  24:6e:96:24:2f:5c  yes  igb0
# igb1         primary  24:6e:96:24:2f:5d  yes  igb1
# ixgbe0       primary  a0:36:9f:c0:fb:b8  yes  ixgbe0
# ixgbe2       primary  24:6e:96:24:2f:58  yes  ixgbe2
# ixgbe1       primary  a0:36:9f:c0:fb:ba  yes  ixgbe1
# ixgbe3       primary  24:6e:96:24:2f:5a  yes  ixgbe3

# [root@headnode (us-east-1) /var/tmp/dc-standup]# dladm show-phys 
# LINK         MEDIA                STATE      SPEED  DUPLEX    DEVICE
# igb0         Ethernet             down       0      half      igb0
# igb1         Ethernet             down       0      half      igb1
# ixgbe0       Ethernet             up         10000  full      ixgbe0
# ixgbe2       Ethernet             up         10000  full      ixgbe2
# ixgbe1       Ethernet             up         10000  full      ixgbe1
# ixgbe3       Ethernet             up         10000  full      ixgbe3

$device->{interfaces}{$iface}{ipaddr} = $ipaddr;
$device->{interfaces}{$iface}{mac}    = $mac;
$device->{interfaces}{$iface}{state}  = $state;
$device->{interfaces}{$iface}{mtu}    = $mtu;

}

1;
