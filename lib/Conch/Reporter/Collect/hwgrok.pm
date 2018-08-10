package Conch::Reporter::Collect::hwgrok;

use strict;
use warnings;

use Path::Tiny;
use IPC::Run3;
use JSON;
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);

# hwgrok is: https://github.com/joyent/hwgrok
# We bundle our own copy in ./bin/hwgrok.

# hwgrok uses libtopo, taking a snapshot every time it's run. This is an
# expensive process, so we should not run it very often. The majority of the
# data we need from top is cacheable; only disk temps and PSU voltages are
# nominally live. If neccessary, we have other ways of getting at those
# metrics.

# TODO Refresh cache when 1hr old.

sub collect {
	my ($device) = @_;

	my $hwgrok = _load_hwgrok_cache();
	$device->{hwgrok} = $hwgrok;

	return $device;
}

sub _load_hwgrok_cache {
	my $file = "/tmp/hwgrok.json";
	my $fp   = path($file);

	my $hwgrok;

	if ( -f $file ) {
		print "=> Using existing hwgrok cache: ";
		my $t0 = [gettimeofday];
		my $json = $fp->slurp_utf8;
		$hwgrok = decode_json $json;
		my $elapsed = tv_interval ($t0);
		printf "%.2fs\n", $elapsed;
	} else {
		print "=> hwgrok cache not found, creating: ";
		my $t0 = [gettimeofday];
		my $cmd = './bin/hwgrok';
		my $stderr;
		my $json;
		run3 $cmd, \undef, \$json, \$stderr;
		$fp->spew_utf8($json);
		$hwgrok = decode_json $json;
		my $elapsed = tv_interval ($t0);
		printf "%.2fs\n", $elapsed;
	}

	return $hwgrok;
}

1;
