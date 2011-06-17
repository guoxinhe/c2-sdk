#!/bin/sh

list="
/c2sdk/kernel.sdk/linux-2.6.git/objects
/c2sdk/u-boot-1.3.0.git/objects
";

#suggest run this script every 10 minutes.

list=`find /c2sdk/  -path \*.git/objects`
for i in $list; do
    chmod -R g+w $i
done

list=`find  /mentor-mirror/build/ -path \*.git/objects`
for i in $list; do
    chmod -R g+w $i
done

