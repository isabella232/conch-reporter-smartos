package netbox::update;

use strict;
use warnings;
use Data::Dumper;
use Path::Tiny;
use JSON;

sub hashFromFile{
  my ($file)=@_;
  my $hash=();
  my $fp = path($file);
  if ( -f $file ) {
    my $json = $fp->slurp_utf8;
    $hash = decode_json $json;
  }
  return $hash;
}

sub updateNetbox{
  my ($device)=@_;
  #print $device->{interfaces};
  my $nbdets=();
  my $creds=netbox::update::hashFromFile('/opt/custom/etc/opstools_secrets');
  if($creds->{netbox_token}){
    my $netbox=hashFromFile('/tmp/netbox-cache.json');
    $nbdets=netbox::update::interfaces::udpateInterfaces($device,$netbox,$creds);
  }else{
     print "ERROR: updateNetbox : no creds could be found for netbox!";
  }
  $device->{netbox}=$nbdets;
  return $device;
}

1;
