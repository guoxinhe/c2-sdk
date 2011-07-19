#!/bin/sh

CONTENT=`sw_media`
SDK_TAG=`date -d tomorrow +%y%m%d`

for i in $CONTENT; do
    echo "updating $i"
    if [ -e $i ]; then
        cvs -q update -CAPd $i
    else
        cvs -q co $i
    fi
    echo "tagging $i"
    cvs -q tag -R -F $SDK_TAG $i
done
echo "tag done"

