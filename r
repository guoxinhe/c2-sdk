#!/bin/sh
RES_COL=10
round="\ | / - " #"+ x X o 0 @ "
a=0; while true; do for r in $round; do a=$((a+1));
echo -en \\033[${RES_COL}G  "`whoami` on `hostname`:`pwd` `date`  wait $a Press ctrl+C to enter console $r";sleep 1; done; done
