#!/bin/sh

TOP=`pwd`/test

DATE=`date +%y%m%d`
SDK_TARGET_ARCH=jazz2
MAJOR=1
MINOR=0
BRANCH=1
TAGVER=14

update_envs()
{
CANDIDATE=${BRANCH}-${TAGVER}
CVS_TAG=${SDK_TARGET_ARCH}-SDK-${MAJOR}_${MINOR}-${CANDIDATE}
SDK_VERSION_ALL=$SDK_TARGET_ARCH-sdk-${MAJOR}.${MINOR}-${CANDIDATE}
S200_DIR=/sdk/$SDK_TARGET_ARCH/rel/candidate/c2-$SDK_TARGET_ARCH-sdk-${MAJOR}.${MINOR}-${BRANCH}/${MAJOR}.${MINOR}-${CANDIDATE}
dirsdk=c2-$SDK_TARGET_ARCH-sdk-${MAJOR}.${MINOR}-${BRANCH}
dirc2box=C2Box-${MAJOR}.${MINOR}-${BRANCH}
}
this_help()
{
    cat <<HELPTEXT
    usage ${0##*/} [-top target-folder ] [ -arch=jazz2 ] [ -major=1 ] [ -minor=0 ] [ -branch=1 ] [ -tagver=8 ]
    example for "Create SDK release link for $S200_DIR"
        $0 -top `pwd`/test -arch=$SDK_TARGET_ARCH -major=$MAJOR -minor=$MINOR -branch=$BRANCH -tagver=$TAGVER

    options
        --full   create full version link
        --brief  create brief version link
        --tree   create tree

    Default settings
        MAJOR=             $MAJOR
        MINOR=             $MINOR
        BRANCH=            $BRANCH
        TAGVER=            $TAGVER
        SDK_TARGET_ARCH=   $SDK_TARGET_ARCH

    A SDK releas include three forms: Basic, Premium, Advance
    * The Basic package will contains:
          o devtools(source & bin),
          o boot loader(source & bin),
          o kernel(source and bin),
          o media software(bin/lib),
          o PVR application(source and bin),
          o C2 goodies(source and bin),
          o Qt(source). 
    * The Premium package will contains:
          o Basic packages
          o media software(codec source under GPL)
          o media software documents. 
    * The Advance release will contains:
          o Premium release,
          o selected codec under NDA and C2’s IP
          o C2-Box application(source & bin)
          o GFX_2D (source)
          o HDMI (source)
          o NAND (bin)
          o dv codec docs
          o encoder docs
          o The advance package release is to be handled case by case. 

    More refs: https://access.c2micro.com/index.php/Media_Software_SDK#SDK_Release_packages

HELPTEXT
}
update_envs

if [ $# -eq 0 ] ; then
    this_help
    exit 0
fi
CONFIG_FULL=
while [ $# -gt 0 ];do
    case $1 in
    -top)         TOP=$2;        shift 2;;
    -arch=*)   SDK_TARGET_ARCH=${1#-arch=}; shift;;
    -major=*)  MAJOR=${1#-major=}; shift;;
    -minor=*)  MINOR=${1#-minor=}; shift;;
    -branch=*) BRANCH=${1#-branch=}; shift;;
    -tagver=*) TAGVER=${1#-tagver=}; shift;;
    -h|--help|-\?|\?) this_help;exit 0;shift;;
    --full)    CONFIG_FULL=y; shift;;
    --brief)   CONFIG_FULL= ; shift;;
    --tree)    CONFIG_TREE=y; shift;;
    *)
        echo unknown command $1
	exit 0
        ;;
    esac
done
update_envs

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
            softlink $i $dirc2box/Basic/$rname  
            [ $CONFIG_FULL ] && softlink $i $dirc2box/Premium/$rname
            ;;
        *)  softlink $i $dirc2box/Premium/$rname
            ;;
        esac
	;;

    *)
        case $rname  in
        *sw_media-src-all* | *sw_c2apps-src* | *spi_rom* | *diag_rom* | *QA* | *test* | \
        Makefile* | rlog* | log* | *.sh | *.txt)
            echo does not link $i
	    ;;
        *sw_media-bin.tar.gz)
            softlink $i $dirsdk/Basic/$rname
            [ $CONFIG_FULL ] && softlink $i $dirsdk/Premium/$rname
            [ $CONFIG_FULL ] && softlink $i $dirsdk/Advance/$rname
	    ;;
        *-gfx_2d-bin.tar.gz)
            softlink $i $dirsdk/Basic/$rname
            [ $CONFIG_FULL ] && softlink $i $dirsdk/Premium/$rname
            [ $CONFIG_FULL ] && softlink $i $dirsdk/Advance/$rname
            ;;
        *sw_media-src.tar.gz  | *sw_media-doc.tar.gz)
            softlink $i $dirsdk/Premium/$rname
            [ $CONFIG_FULL ] && softlink $i $dirsdk/Advance/$rname
	    ;;
        *-dv-docs.tar.gz | *-encoder-docs.tar.gz | *-gfx_2d-src.tar.gz | *-hdmi-src.tar.gz | *-Karaoke-Widget-docs.tar.gz)
            softlink $i $dirsdk/Advance/$rname
            ;;
        *)
            softlink $i $dirsdk/Basic/$rname
            [ $CONFIG_FULL ] && softlink $i $dirsdk/Premium/$rname
            [ $CONFIG_FULL ] && softlink $i $dirsdk/Advance/$rname
            ;;
        esac
	;;
    esac
done
if [ $CONFIG_TREE ];then
    tree >/tmp/tree$$.txt
    mv /tmp/tree$$.txt filelist.txt
    sed -i 's/ -> .*//g' filelist.txt
fi
popd
echo "Create SDK release link for $S200_DIR"  : done
[ $CONFIG_TREE ] && echo "files are listed in $TOP/filelist.txt"
echo "Please check $TOP before release"
