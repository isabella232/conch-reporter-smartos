package Conch::Reporter::Collect::System::Uptime;

use strict;
use warnings;

use JSON;
use POSIX qw(strftime);

sub collect {
	my ($device) = @_;
	my $kstat = `/usr/bin/kstat -j unix:0:system_misc:boot_time`;
	my $boot  = decode_json $kstat;
	my $boot_time = $boot->[0]->{data}->{boot_time};

	my $fmt_uptime = strftime("%Y/%m/%d %H:%M:%S%z",localtime($boot_time));

	$device->{conch}->{uptime_since} = $fmt_uptime;
	return $device;
}

1;
