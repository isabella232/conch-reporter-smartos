package Conch::Reporter::Collect::Network::IPMI;

use strict;
use warnings;

use IPC::Cmd qw[can_run run run_forked];

sub collect {
	my ($device) = @_;

	$device = _ipmi_lan($device);

	return $device;
}

sub _v4bits{
  my $bits=0;
  my @q_arr=split(/\./,$_[0]);
  for (@q_arr){
    my $bin=sprintf("%b",$_);
    $bin=~s/0//g;
    my $l=split('',$bin);
    $bits+=$l;
  }
  return $bits;
}

sub _ipmi_lan {
	my ($device) = @_;

	my $cmd = "/usr/sbin/ipmitool lan print 1";
	my $buffer;
	scalar run( command => $cmd,
		verbose => 0,
		buffer  => \$buffer,
		timeout => 20 );

	# See examples/ipmi_lan.txt
	my %ipmi_hash;
	foreach my $line (split/\n/, $buffer) {
		chomp $line;
		my ($k, $v) = split(/ : /, $line);
		$k =~ s/^\s+|\s+$//g;
		$v =~ s/^\s+|\s+$//g;
		$ipmi_hash{$k}=$v;
	}
	if($ipmi_hash{'IP Address'}){
		my $bits=_v4bits($ipmi_hash{'Subnet Mask'});
		$device->{conch}{interfaces}{ipmi1}{ipaddr} = $ipmi_hash{'IP Address'}.'/'.$bits;
	}

	$device->{conch}{interfaces}{ipmi1}{mac}    = $ipmi_hash{'MAC Address'} if $ipmi_hash{'MAC Address'};
	# XXX Could make this smarter by detecting Dell vs SMCI. Or not.¬
	# racadm getniccfg can tell you if the DRAC link is up, for instance.¬
	$device->{conch}{interfaces}{ipmi1}{product} = "OOB";
	$device->{conch}{interfaces}{ipmi1}{vendor}  = "Intel";
	$device->{conch}{interfaces}{ipmi1}{class}   = "phys";

	return $device;
}
1;
