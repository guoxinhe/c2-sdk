#!/bin/sh
RES_COL=10
a=0; while true; do a=$((a+1));  
echo -en \\033[${RES_COL}G  "`whoami` on `hostname`:`pwd` `date`  wait $a Press ctrl+C to enter console";sleep 1; done
