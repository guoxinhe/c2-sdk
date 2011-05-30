#!/bin/sh

cd /home/hguo/maintree-jazz2l
export CVSROOT=:pserver:hguo@cvs.c2micro.com:/cvsroot
BRANCH="jazz2l-SDK-0_5-1_Branch"
CONTENT=`cat sdk_content-jazz2l-SDK-0_5-1_Branch`

cvslog=cvs.log
progresslog=progress.log
# update all SDK codes
echo "Create Branch"    >>$progresslog
for i in $CONTENT; do
    echo "branching $i"    >>$cvslog
    echo "`date` branching $i"    >>$progresslog
    cvs -q co -AP $i    >>$cvslog
    #cvs -q update -CAPd $i
    cvs -q tag -b $BRANCH $i    >>$cvslog
done
echo "branch done"    >>$progresslog


CONTENT=`cat sdk_content`
echo "CVS update"
for i in $CONTENT; do
    echo "updating $i"    >>$cvslog
    echo "`date` updating $i"    >>$progresslog
    cvs -q update -CAPd -r $BRANCH $i    >>$cvslog
done
echo "update done"   >>$progresslog


