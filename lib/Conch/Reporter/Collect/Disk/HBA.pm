package Conch::Reporter::Collect::Disk::HBA;

use strict;
use warnings;

use Path::Tiny;
use IPC::Cmd qw[can_run run run_forked];

sub collect {
	my ($device) = @_;

	my @attrib = qw/device-name driver-version firmware-version
		hardware-version manufacturer model modelname revision-id
		serialnumber subsystem-name unit-address vendor-name/;

	my $list = _get_hba_list($device->{hwgrok}->{'pci-devices'});

	my @hba;
	foreach my $l (@{$list}) {
		my $k = _get_prtconf_entry($l);
		my $h = {};
		foreach my $name (keys %{$k}) {
			if ( grep { $name eq $_ } @attrib ) {
				$h->{$name} = $k->{$name};
			}
		}
		push @hba, $h;
	}

	$device->{conch}->{hba} = \@hba;

	return $device;
}

sub _get_prtconf_entry {
	my ($devpath) = @_;

	my $file = '/tmp/conch.hba.prtconf';
	my $cmd = "prtconf -v /devices/$devpath";
	my( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) =
        run( command => $cmd, verbose => 0, timeout => 30 );
	my $out = path($file)->spew(@$stdout_buf);
	my $fh = path($file)->filehandle;
	my $k = {};
	my $name;

	while (<$fh>) {
		s/^\s+|\s+$//g;
		if (/^Driver properties:$/) {
			while (<$fh>) {
				($k, $name) = _parse_line($k, $name, $_);
				last if (/^Hardware properties:$/);
			}
		}
	}

	return $k;
}

sub _parse_line {
	my ($k, $name, $l) = @_;
	chomp $l;
	$l =~ s/^\s+|\s+$//g;
	if ($l =~ /^name=/) {
		my @line = split(/ /, $l);
		$name = $line[0];
		$name =~ s/name=//;
		$name =~ s/'//g;
	}

	if ($l =~ /^value=/) {
		$l =~ s/value=//;
		$l =~ s/'//g;
		$k->{lc($name)} = $l;
	}

	return ($k, $name);
}

sub _get_hba_list {
	my ($pci) = @_;

	my @hba;

	foreach my $d (@{$pci}) {
		if ($d->{'device-driver-name'} =~ /mpt_sas/) {
			push @hba, $d->{'device-path'};
		}
	}

	return \@hba;
}

1;
