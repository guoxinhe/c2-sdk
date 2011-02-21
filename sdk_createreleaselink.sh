#!/bin/sh

TOP=`pwd`/test

DATE=`date +%y%m%d`
SDK_TARGET_ARCH=jazz2
MAJOR=1
MINOR=0
BRANCH=1
TAGVER=8

if [ $# -eq 0 ] ; then
cat <<HELPTEXT
    usage sdk_createreleaselink.sh [-top target-folder ] [ -arch=jazz2 ] [ -major=1 ] [ -minor=0 ] [ -branch=1 ] [ -tagver=8 ]
    example for "Create SDK release link for /sdk/jazz2/rel/candidate/c2-jazz2-sdk-1.0-1/1.0-1-8"
        sdk_createreleaselink.sh -top `pwd`/test -arch=jazz2 -major=1 -minor=0 -branch=1 -tagver=8

    Default settings
        MAJOR=              1
        MINOR=              0
        BRANCH=             1
        TAGVER=             8
        SDK_TARGET_ARCH=    jazz2

HELPTEXT
    exit 0
fi
while [ $# -gt 0 ];do
    case $1 in
    -top)         TOP=$2;        shift 2;;
    -arch=*)   SDK_TARGET_ARCH=${1#-arch=}; shift;;
    -major=*)  MAJOR=${1#-major=}; shift;;
    -minor=*)  MINOR=${1#-minor=}; shift;;
    -branch=*) BRANCH=${1#-branch=}; shift;;
    -tagver=*) TAGVER=${1#-tagver=}; shift;;
    *)
        echo unknown command $1
	exit 0
        ;;
    esac
done
CANDIDATE=${BRANCH}-${TAGVER}
CVS_TAG=${SDK_TARGET_ARCH}-SDK-${MAJOR}_${MINOR}-${CANDIDATE}
SDK_VERSION_ALL=$SDK_TARGET_ARCH-sdk-${MAJOR}.${MINOR}-${CANDIDATE}
S200_DIR=/sdk/$SDK_TARGET_ARCH/rel/candidate/c2-$SDK_TARGET_ARCH-sdk-${MAJOR}.${MINOR}-${BRANCH}/${MAJOR}.${MINOR}-${CANDIDATE}
dirsdk=c2-$SDK_TARGET_ARCH-sdk-${MAJOR}.${MINOR}-${BRANCH}
dirc2box=C2Box-${MAJOR}.${MINOR}-${BRANCH}

softlink()
{
    [ -h $2 ] && rm $2 
    ln -s $1 $2
}
if [ ! -d $S200_DIR ]; then
    echo "can not find folder $S200_DIR"
    exit 0
fi
mkdir -p $TOP
pushd $TOP
[ -d $dirsdk ] && done=1
[ -d $dirc2box ] && done=1
if [ "$done" = 1 ]; then
    echo link already done. remove it manually for relink them.
    exit 0
fi
mkdir -p   $dirsdk/Advance/plugins
mkdir -p   $dirsdk/Basic
mkdir -p   $dirsdk/Premium
mkdir -p $dirc2box/Basic
mkdir -p $dirc2box/Premium

flist=`find $S200_DIR -type f `
for i in $flist ; do
    pname=${i##*/}
    #pname=`echo $i | sed 's:.*/\(.*\):\1:'`
    rname=`echo $pname | sed "s,${MAJOR}.${MINOR}-${CANDIDATE},${MAJOR}.${MINOR}-${BRANCH},"`    
    #echo $i
    case $i in
    *\/plugins\/*)
        softlink $i $dirsdk/Advance/plugins/$rname
	;;

    *\/c2box\/*)
        case $rname  in
        *c2box-src.tar.gz | *c2box-bin.tar.gz)
            softlink $i $dirc2box/Basic/$rname  ;;
        *)  softlink $i $dirc2box/Premium/$rname;;
        esac
	;;

    *)
        case $rname  in
        *sw_media-src-all.tar.gz | Makefile* | *.sh)
            echo does not link $i
	    ;;
        *sw_media-bin.tar.gz)
            softlink $i $dirsdk/Basic/$rname
            softlink $i $dirsdk/Premium/$rname
	    ;;
        *sw_media-src.tar.gz  | *sw_media-doc.tar.gz)
            softlink $i $dirsdk/Premium/$rname
	    ;;
        *-gfx_2d-bin.tar.gz)
            softlink $i $dirsdk/Advance/$rname
            softlink $i $dirsdk/Basic/$rname
            softlink $i $dirsdk/Premium/$rname
            ;;
        *-dv-docs.tar.gz | *-encoder-docs.tar.gz | *-gfx_2d-src.tar.gz | *-hdmi-src.tar.gz | *-Karaoke-Widget-docs.tar.gz)
            softlink $i $dirsdk/Advance/$rname
            ;;
        *)
            softlink $i $dirsdk/Basic/$rname
            softlink $i $dirsdk/Premium/$rname
            ;;
        esac
	;;
    esac
done

popd
echo "Create SDK release link for $S200_DIR"  : done
echo "Please check $TOP before release"
