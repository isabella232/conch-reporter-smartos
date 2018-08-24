#!/bin/bash

V=$( git show --oneline | head -1 | awk '{print $1}' )
F="conch-reporter-smartos-$V.tar.gz"
cd ../
tar -czf $F conch-reporter-smartos
echo "$PWD/$F"
