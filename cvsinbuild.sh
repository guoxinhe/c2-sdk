#!/bin/sh

if [ ! -d sdk ]; then
    cvs -q co -A -r $CVS_TAG -d sdk projects/sw/sdk
fi

echo "Check out sdk work directory"
cvs -q update -CAPd -r $CVS_TAG

cvs -Q commit -m$SDK_TAG Makefile vertical/Makefile.pvr



echo "CVS update"
for i in $CONTENT; do
    echo "updating $i"
    if [ -e $i ]; then
        cvs -q update -CPd $i
    else
        cvs co $i
    fi
done
echo "update done"


cd $WORKDIR
for i in $CONTENT; do
    echo "tagging $i"
    cvs -q tag -R -F $SDK_TAG $i
done
echo "tag done"

