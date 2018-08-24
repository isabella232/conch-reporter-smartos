#!/bin/bash

set -e
set -x

export SSL_CERT_FILE=$PWD/cacert.pem

while true ; do
	date
	./collect.pl
	cat /tmp/conch-report.json | json conch | ./bin/conch -c /var/tmp/.conch.json api post /device/$( sysinfo | json 'Serial Number' )
	date
	sleep 3600
done
