package Conch::Reporter::Collect::hwgrok;

use strict;
use warnings;

use Carp;
use Path::Tiny;
use JSON::PP;
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
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

	my $hwgrok;

	# XXX Add regen interval per the cache-aware disk collectors.
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

		my $cmd = './bin/hwgrok | grep -v ^$';
		my( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) =
			run( command => $cmd, verbose => 0, timeout => 30 );
		if( $success ) {
			$fp->spew_utf8($stdout_buf);
			$hwgrok = decode_json $stdout_buf;
			my $elapsed = tv_interval ($t0);
			printf "%.2fs\n", $elapsed;
		}
	}

	return $hwgrok;
}

1;
