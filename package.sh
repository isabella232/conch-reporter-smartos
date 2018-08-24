#!/bin/bash

V=$( git show --oneline | head -1 | awk '{print $1}' )
echo $V > VERSION.txt

F="conch-reporter-smartos-$V.tar.gz"
cd ../
tar -czf $F conch-reporter-smartos
echo "$PWD/$F"

echo "Make a symlink wherever you're storing this on Manta:"
echo "mln ~~/public/conch-reporter-smartos-latest.tar.gz ~~/public/$F"
