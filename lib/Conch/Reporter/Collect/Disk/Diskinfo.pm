package Conch::Reporter::Collect::Disk::Diskinfo;

use strict;
use warnings;

use Carp;
use Path::Tiny;
use IPC::Run3;
use JSON;
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);

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
    if (!defined($diskinfo->{updated}) || (time()-$diskinfo->{updated}) > $update_interval) {
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
  my @output = `/usr/bin/diskinfo -Hcp`;
  my $diskinfo = {};
  foreach my $line (@output) {
    chomp $line;
    my @disk = $line =~ m/^(.*)\t(.*)\t(.*)\t(.*)\t(.*)\t(.*)\t(.*)\t(.*)/;
    next unless scalar @disk > 5;
    $diskinfo->{$disk[4]} = \@disk;
  }
  $diskinfo->{updated} = time();

  return $diskinfo;
}

1;
