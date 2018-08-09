package Conch::Reporter::Collect::Network::IPMI;

use strict;
use warnings;

sub collect {
	my ($device) = @_;

	$device = _ipmi_lan($device);

	return $device;
}

sub _ipmi_lan {
	my ($device) = @_;

	my $cmd = `/usr/sbin/ipmitool lan print 1`;
	# See examples/ipmi_lan.txt

	foreach my $line (split/\n/, $cmd) {
		chomp $line;
		my ($k, $v) = split(/ : /, $line);
		$k =~ s/^\s+|\s+$//g;
		$v =~ s/^\s+|\s+$//g;

		if ( $k eq "IP Address" ) {
			$device->{interfaces}{ipmi1}{ipaddr} = $v;
		}

		if ( $k eq "MAC Address" ) {
			$device->{interfaces}{ipmi1}{mac}    = $v;
		}

		# XXX Could make this smarter by detecting Dell vs SMCI. Or not.¬
		# racadm getniccfg can tell you if the DRAC link is up, for instance.¬
		$device->{interfaces}{ipmi1}{product} = "OOB";
		$device->{interfaces}{ipmi1}{vendor}  = "Intel";
		$device->{interfaces}{ipmi1}{class}   = "phys";
	}

	return $device;
}

1;
