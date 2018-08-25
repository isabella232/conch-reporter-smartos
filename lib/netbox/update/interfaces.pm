package netbox::update::interfaces;

use strict;
use warnings;

use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);
use Data::Dumper;
use JSON;
use Path::Tiny;
use netbox::update::netbox;


sub udpateInterfaces{
  my ($device,$netbox,$creds)=@_;
  my $t0 = [gettimeofday];
  my $site=$device->{sysinfo}{"Datacenter Name"};
  my $hostname=$device->{sysinfo}{"Hostname"};
  my $devints=$device->{conch}{interfaces};
  my $nbxints=$netbox->{interfaces};
  my @ipupdate;
  my @ipdelete;
  my @retints;
  for my $int (keys %{$devints}){
    my ($devip,$nbxip)=('null','null');
    $devip=$devints->{$int}{ipaddr} if $devints->{$int}{ipaddr};
    $nbxip=$nbxints->{$int}{ipaddr} if $nbxints->{$int}{ipaddr};
    if($devip ne $nbxip){
      push(@ipupdate,$int)
    }
  }
  for my $int (keys %{$nbxints}){
    if(!$devints->{$int}){
      if($nbxints->{$int}{ipaddr}){
        push (@ipdelete,$int);
      }
    }
  }
  if(@ipupdate<1 && @ipdelete<1){
    print "=> Netbox Interfaces no changes found: ";
  }else{
    print "=> Netbox Interfaces updating interfaces: ";
    my %exceptions=("us-west-a"=>'hold',"us-west-b"=>'hold',"us-east-3b"=>'hold');
    my $squery='';
    if (!$exceptions{$site}){
      my $siteid=netbox::update::netbox::getID($creds,'dcim/sites/?limit=1&name='.$site);
      $squery='&site_id='.$siteid;
    }
    #add or update current interfaces
    for my $int (@ipupdate){
      my $int_hash=$devints->{$int};
      if($int_hash->{ipaddr}){
        $int_hash->{int}=$int;
        $int_hash->{creds}=$creds;
        $int_hash->{squery}=$squery;
        $int_hash->{site}=$site;
        $int_hash->{hostname}=$hostname;
        my $ipret=updateIP($int_hash,'update');
        push(@retints,$ipret);
      }
    }
    #remove interface which are no longer present
    for my $int (@ipdelete){
      my $int_hash=$nbxints->{$int};
      if($int_hash->{ipaddr}){
        $int_hash->{int}=$int;
        $int_hash->{creds}=$creds;
        $int_hash->{squery}=$squery;
        my $ipret=updateIP($int_hash,'delete');
        push(@retints,$ipret);
      }
    }

    #add cache file for curent devints
    my $netboxcache->{interfaces}=$devints;
    my $json = encode_json $netboxcache;
    my $file = '/tmp/netbox-cache.json';
    my $fp = path($file);
    $fp->spew_utf8($json);
  }
  my $elapsed = tv_interval ($t0);
  printf "%.2fs\n", $elapsed;
  return \@retints;
}

sub updateIPs{
  my ($i_arr,$i_hash,$type)=@_;

}

sub updateIP{
  my ($int,$type)=@_;
  my $ip=$int->{ipaddr};
  my $pfq='contains='.$ip;
  $pfq.=$int->{squery} if $int->{squery};
  my $pfinfo=netbox::update::netbox::goNetbox($int->{creds},'ipam/prefixes/?'.$pfq,'','');
  if($pfinfo->{count}==1){
    my $vrfid=$pfinfo->{results}[0]{vrf}{id};
    my $payload;
    $payload->{address}=$ip;
    $payload->{vrf}=$vrfid;
    $payload->{tenant}=$pfinfo->{results}[0]{tenant}{id};
    $payload->{status}=1;
    $payload->{description}=$int->{site}.' '.$int->{hostname}.' '.$int->{int};
    my $ipq='address='.$ip;
    $ipq.='&vrf_id='.$vrfid if $vrfid;
    $payload=$type if $type eq 'delete';
    my $ipid=netbox::update::netbox::getID($int->{creds},'ipam/ip-addresses/?'.$ipq,'','');
    my $ipret=netbox::update::netbox::goNetbox($int->{creds},'ipam/ip-addresses/',$ipid,$payload);
    if($ipret->{delete}){
      $ipret->{hostname}=$int->{hostname};
      $ipret->{int}=$int->{int};
      $ipret->{ip}=$ip;
    }
    return $ipret;
  }else{
    print "updateIP Error: ".$pfinfo->{count}." found\n";
  }
}

1;
