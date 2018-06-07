package Conch::Reporter::Collect::Ohai;

use strict;
use warnings;

use Data::Printer;

use Exporter 'import';
our @EXPORT = qw( ohai );


sub ohai {
  my $filename = "/tmp/ohai.json";
  my $generate_ohai = `/usr/bin/ohai > $filename 2> /tmp/ohai.err`;

  my $json_text = do {
     open(my $json_fh, "<:encoding(UTF-8)", $filename)
        or die("Can't open $filename\": $!\n");
     local $/;
     <$json_fh>
  };

  my $json = JSON->new;
  my $ohai = $json->decode($json_text);

  return $ohai;
}

1;
