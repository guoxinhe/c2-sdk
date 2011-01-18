#!/bin/sh

if [ "$1" == "" ]; then
    echo "Error: please input CVS path"
    exit -1
fi

CVS_PATH=/db/cvsroot/$1
if [ ! -d $CVS_PATH ]; then
    echo "Error: Couldn't find path $CVS_PATH in CVS"
    exit -1
fi

echo "`date` : Search deadlocks in $CVS_PATH"

SECONDS_NOW=`date +%s`
LOCKED_FILES=`find $CVS_PATH -name "#cvs.*"`

for i in $LOCKED_FILES ; do
    SECONDS_FILE=`date -r $i +%s 2>/dev/null`
    if [ "$SECONDS_FILE" == "" ]; then
        continue
    fi
    SHIFT=`expr $SECONDS_NOW - $SECONDS_FILE`
    if [ "$SHIFT" -ge "1800" ]; then # 30 minutes
        echo "file $i, date shift: $SHIFT"
        rm $i
    fi
done
