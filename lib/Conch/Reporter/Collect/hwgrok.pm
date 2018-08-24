package Conch::Reporter::Collect::hwgrok;

use strict;
use warnings;

use Carp;
use Path::Tiny;
use JSON::PP;
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
use File::stat;
use IPC::Cmd qw[can_run run run_forked];

# hwgrok is: https://github.com/joyent/hwgrok
# We bundle our own copy in ./bin/hwgrok.

# hwgrok uses libtopo, taking a snapshot every time it's run. This is an
# expensive process, so we should not run it very often. The majority of the
# data we need from topo is cacheable; only disk temps and PSU voltages are
# nominally live. If neccessary, we have other ways of getting at those
# metrics.

sub collect {
	my ($device) = @_;

	my $hwgrok = _load_hwgrok_cache();
	$device->{hwgrok} = $hwgrok;

	return $device;
}

sub _load_hwgrok_cache {
	my $file = "/tmp/hwgrok.json";
	my $fp   = path($file);

	my $update_interval = 60 * 60; # Every hour

	my $hwgrok;

	my $t0 = [gettimeofday];
	if ( -f $file ) {
		my $sb = stat($file);
		if ( (time() - $sb->mtime) > $update_interval) {
			print "=> Updating existing hwgrok cache: ";
			$hwgrok = _run_hwgrok();
		} else {
			print "=> Using existing hwgrok cache: ";
			my $json = $fp->slurp_utf8;
		}
	} else {
		print "=> hwgrok cache not found, creating: ";
		$hwgrok = _run_hwgrok();
	}

	my $elapsed = tv_interval ($t0);
	printf "%.2fs\n", $elapsed;

sub _run_hwgrok {
	my $file = "/tmp/hwgrok.json";
	my $fp   = path($file);

	my $cmd = './bin/hwgrok | grep -v ^$';

	my $buffer;
	scalar run( command => $cmd,
		verbose => 0,
		buffer  => \$buffer,
		timeout => 30 );
	my $hwgrok = decode_json $buffer;
	$fp->spew_utf8($buffer);
	return $hwgrok;
}

	return $hwgrok;
}

1;
