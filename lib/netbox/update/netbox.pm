package netbox::update::netbox;

use strict;
use warnings;

use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);

use IPC::Cmd qw[can_run run run_forked];
use JSON::PP;

sub goNetbox{
  my ($creds,$path,$id,$p)=@_;
  my $payload='';
  my $rtype='GET';
  if($id){
    $rtype='PATCH';
    $path.=$id.'/';
    if($p eq 'delete'){
      $rtype='DELETE'
    }else{
      $payload=encode_json($p);
    }
  }elsif($p){
    $rtype='POST';
    $payload=encode_json($p);
  }
  my $cmd='/usr/bin/curl -s -k -X '.$rtype;
  $cmd.=' "https://'.$creds->{netbox_host}.'/api/'.$path.'"';
  $cmd.=" -d '".$payload."'";
  $cmd.=' -H "Content-Type: application/json"';
  $cmd.=' -H "accept: application/json" -H "Authorization: Token '.$creds->{netbox_token}.'"';
  my $buffer;
  scalar run( command => $cmd,verbose => 0, buffer  => \$buffer, timeout => 20 );
  if($rtype eq 'DELETE' && !$buffer){
    my $json_out->{delete}=$path;
    return $json_out;
  }else{
    my $json_out = eval { decode_json($buffer) };
    if($@){
      my $error->{error}="ERROR: failed to decode JSON: $path : $@";
      return $error;
    }else{
      return $json_out;
    }
  }

}

sub getID{
  my ($c,$p)=@_;
  my $res=goNetbox($c,$p,'','');
  if($res->{error}){
    return "ERROR : getID :  ".$p.":".$res->{error}."\n";
  }else{
    my $rc=@{$res->{results}};
    if($rc==1){
      return $res->{results}[0]{id};
    }elsif($rc<1){
      return 0;
    }else{
      return "ERROR : getID : $rc results for $p";
    }
  }
}

1;
