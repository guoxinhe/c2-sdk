#!/bin/sh

# update all SDK codes

CONTENT=`cat sdk_content`

# add tag 
if [ $# -lt "2" ]
then
  exit 1
fi
if [ $1 != "sure" ]
then
  echo "Correct format: ./tag.sh sure [TAG]"
  exit 1
fi

echo "CVS update and tag"
SDK_TAG=$2
ARCH=`echo $SDK_TAG |awk -F'[-_]' '{print $1}'`
MAJOR=`echo $SDK_TAG |awk -F'[-_]' '{print $3}'`
MINOR=`echo $SDK_TAG |awk -F'[-_]' '{print $4}'`
BRANCH=`echo $SDK_TAG |awk -F'[-_]' '{print $5}'`
CANDIDATE=`echo $SDK_TAG |awk -F'[-_]' '{print $6}'i`
if [ "$ARCH" = "jazz2" ]; then
    GCC_ARCH=TANGO
    KERNEL=2.6.23
elif [ "$ARCH" = "jazz2l" ]; then
    GCC_ARCH=JAZZ2L
    KERNEL=2.6.23
elif [ "$ARCH" = "jazz2t" ]; then
    GCC_ARCH=JAZZ2T
    KERNEL=2.6.23
else
    GCC_ARCH=JAZZB
    KERNEL=2.6.14
fi

pushd projects/sw/sdk
sed -i "/^SDK_KERNEL_VERSION/s/?=.*/?= $KERNEL/"    Makefile
sed -i "/^SDK_TARGET_ARCH/s/?=.*/?= $ARCH/"         Makefile
sed -i "/^SDK_TARGET_GCC_ARCH/s/?=.*/?= $GCC_ARCH/" Makefile
sed -i "/^MAJOR/s/:=.*/:= $MAJOR/"                  Makefile
sed -i "/^MINOR/s/:=.*/:= $MINOR/"                  Makefile
sed -i "/^BRANCH/s/:=.*/:= $BRANCH/"                Makefile
sed -i "/^CANDIDATE/s/-.*/-$CANDIDATE/"             Makefile
sed -i "/^SDK_KERNEL_VERSION/s/?=.*/?= $KERNEL/"    vertical/Makefile.pvr
sed -i "/^SDK_TARGET_ARCH/s/?=.*/?= $ARCH/"         vertical/Makefile.pvr
sed -i "/^SDK_TARGET_GCC_ARCH/s/?=.*/?= $GCC_ARCH/" vertical/Makefile.pvr
sed -i "/^MAJOR/s/:=.*/:= $MAJOR/"                  vertical/Makefile.pvr
sed -i "/^MINOR/s/:=.*/:= $MINOR/"                  vertical/Makefile.pvr
sed -i "/^BRANCH/s/:=.*/:= $BRANCH/"                vertical/Makefile.pvr
sed -i "/^CANDIDATE/s/-.*/-$CANDIDATE/"             vertical/Makefile.pvr
cvs -Q commit -m$SDK_TAG Makefile                   vertical/Makefile.pvr
popd

for i in $CONTENT; do
    echo "updating $i"
    if [ -e $i ]; then
        cvs -q update -CPd $i
    else
        cvs co $i
    fi
    echo "tagging $i"
    cvs -q tag -R -F $SDK_TAG $i
done
echo "tag done"

