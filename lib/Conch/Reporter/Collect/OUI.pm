package Conch::Reporter::Collect::OUI;

use strict;
use warnings;

use Path::Tiny;
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);

# Previously used Net::MAC::Vendor, but it relied on XS modules that make
# this codebase difficult to run on SmartOS GZ. So now we do this.

sub lookup {
	my ($mac) = @_;
	my $cache = _load_oui_cache();
	$mac =~ s/:|-//g;
	my $oui   = lc(substr($mac,0,6));

	foreach my $vendor (keys %{$cache}) {
		if ( grep /$oui/, @{$cache->{$vendor}} ) {
			return $vendor;
		}
	}
	return undef;
}

sub _load_oui_cache {
	my $oui = {};
	if (-f "./oui.cache") {
		print "=> Loading OUI cache: ";
		my $t0 = [gettimeofday];

		my $file = path("./oui.cache");
		my $fh = $file->filehandle;
		while (<$fh>) {
			next unless $_ =~ /\(hex\)/;
			my ($mac, $vendor) = split(/\(hex\)/, $_);
			chomp $mac;
			chomp $vendor;
			$mac =~ s/^\s+|\s+$//g;
			$mac =~ s/-//g;
			$vendor =~ s/^\s+|\s+$//g;
			push @{$oui->{$vendor}}, lc($mac);
		}
		
		my $elapsed = tv_interval ($t0);
		printf "%.2fs\n", $elapsed;
	} else {
		die "OUI cache file not found, bailing.";
	}

	return $oui;
}

1;
