package Conch::Reporter::Collect::Disk::Diskinfo;

use strict;
use warnings;

use Carp;
use Path::Tiny;
use IPC::Run3;
use JSON;
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
use File::stat;

use Data::Printer;

sub collect {
	my ($device) = @_;

	my $diskinfo = _load_diskinfo_cache();
	$device->{diskinfo} = $diskinfo;

	return $device;
}

sub _load_diskinfo_cache {
	my $file = "/tmp/diskinfo.json";
	my $update_interval = 60 * 60; # Every hour
	my $fp = path($file);
	my $diskinfo;

	if ( -f $file ) {
		my $t0 = [gettimeofday];
		my $json = $fp->slurp_utf8;
		$diskinfo = decode_json $json;

		my $sb = stat($file);

		if ( (time() - $sb->mtime) > $update_interval) {
			print "=> Updating existing diskinfo cache: ";
			$diskinfo = _run_diskinfo();
			$fp->spew_utf8(encode_json $diskinfo);
		} else {
			print "=> Using existing diskinfo cache: ";
		}
		my $elapsed = tv_interval ($t0);
		printf "%.2fs\n", $elapsed;
	} else {
		print "=> diskinfo cache not found, creating: ";
		my $t0 = [gettimeofday];
		$diskinfo = _run_diskinfo();
		$fp->spew_utf8(encode_json $diskinfo);
		my $elapsed = tv_interval ($t0);
		printf "%.2fs\n", $elapsed;
	}

	return $diskinfo;
}

sub _run_diskinfo {
	my $diskinfo = {};

	# TYPE DISK VID PID SERIAL SIZE FLRS LOCATION
	my @compact = `/usr/bin/diskinfo -Hcp`;
	foreach my $line (@compact) {
		chomp $line;
		my @disk = split(/\t+/,$line);

		# We don't have USB serial numbers on SmartOS. c.f. RFD 147.
		# This workaround is likely pretty fragile, if USB keys are getting
		# moved around a lot -- which is why we relied on SNs in the first
		# place.
		if ($disk[4] eq "-") {
			# If we don't have the SN, set this field to the device ID, so we
			# at least have something.
			$disk[4] = $disk[1];
		}

		my $serial = $disk[4];

		my ($enclosure,$slot) = split(/,/, $disk[7]);

		my ($fault,$locate,$removable,$ssd) = split(//,$disk[6]);

		$diskinfo->{$serial}->{device}    = $disk[1];
		$diskinfo->{$serial}->{vendor}    = $disk[2];
		$diskinfo->{$serial}->{model}     = $disk[3];
		$diskinfo->{$serial}->{size}      = $disk[5];
		$diskinfo->{$serial}->{enclosure} = $enclosure;
		$diskinfo->{$serial}->{slot}      = $slot;
		$diskinfo->{$serial}->{fault}     = $fault      eq "F" ? 1 : 0;
		$diskinfo->{$serial}->{locate}    = $locate     eq "L" ? 1 : 0;
		$diskinfo->{$serial}->{removable} = $removable  eq "R" ? 1 : 0;
		$diskinfo->{$serial}->{ssd}       = $ssd        eq "S" ? 1 : 0;
	}

	return $diskinfo;
}

1;
