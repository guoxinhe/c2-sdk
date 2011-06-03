#!/bin/sh
a=0; while true; do a=$((a+1)); clear; 
echo "`whoami` on `hostname`:`pwd` `date`";
if [ $# -gt 0 ] ; then  $@; else ls; fi
echo "----------------------------------------------------------"
echo "soft wait server $a minutes, Press ctrl+C to enter console";sleep 60; done
