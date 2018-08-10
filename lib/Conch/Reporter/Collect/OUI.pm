package Conch::Reporter::Collect::OUI;

use strict;
use warnings;

use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
use Net::MAC::Vendor;

sub lookup {
	my ($mac) = @_;
	return Net::MAC::Vendor::fetch_oui_from_cache($mac);
}

sub _load_oui_cache {
	if (-f "./oui.cache") {
		print "=> Using OUI cache: ";
		my $t0 = [gettimeofday];
		my $cache_load =
			Net::MAC::Vendor::load_cache("./oui.cache", "/var/tmp/oui.out");
		my $elapsed = tv_interval ($t0);
		printf "%.2fs\n", $elapsed;
	} else {
		print "=> OUI cache not found, fetching from IEEE: ";
		my $t0 = [gettimeofday];
		my $cache_load =
			Net::MAC::Vendor::load_cache(undef, "/var/tmp/oui.out");
		my $elapsed = tv_interval ($t0);
		printf "%.2fs\n", $elapsed;
	}
}

1;
