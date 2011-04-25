#!/bin/sh
a=0; while true; do a=$((a+1)); clear; pwd;
[ $# -gt 0 ] && $@
echo "soft wait server $a, Press ctrl+C to enter console";sleep 60; done
