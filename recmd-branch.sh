#!/bin/sh

BRANCH="jazz2-SDK-0_9-4L_Branch"
CONTENT=`cat sdk_content`

# update all SDK codes
echo "Create Branch"
for i in $CONTENT; do
    echo "branching $i"
    cvs -q tag -b $BRANCH $i
done
echo "branch done"

echo "CVS update"
for i in $CONTENT; do
    echo "updating $i"
    cvs -q update -CAPd -r $BRANCH $i
done
echo "update done"

