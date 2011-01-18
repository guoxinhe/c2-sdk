#!/bin/sh

. ~/.bash_profile

## Global and ***simple*** defines used by this, Makefile, cgi scripts
#----------------------------------------------------------------------
export DATE=`date +%y%m%d`
export SDK_TARGET_ARCH=jazz2
BUILD_FOR=daily                              #daily/weekly/branch, default daily
SOURCE_DIR=/build/jazz2/dev/daily/sdk/source
QTINSTALL_NAME=QtopiaCore-4.6.1-generic
export SDK_QT_VERSION=4.6.1 
export SDK_GCC_VERSION=4.0.3
export SDK_KERNEL_VERSION=2.6.23
TOOLCHAIN_PATH2ND=`readlink -f /c2/local/c2/daily-jazz2/bin`

##  Get command line args, override all the configured settings.
#----------------------------------------------------------------------
while [ $# -gt 0 ] ; do
    case $1 in
    -daily)       SOURCE_DIR=/build/jazz2/dev/daily/sdk/source  ;  BUILD_FOR=daily  ; shift  ;;
    -weekly)      SOURCE_DIR=/build/jazz2/dev/weekly/sdk/source ;  BUILD_FOR=weekly ; shift  ;;
    -branch)      SOURCE_DIR=/build/jazz2/rel/sdk/source        ;  BUILD_FOR=branch ; shift  ;;
    -checkout)    CONFIG_BUILD_CHECKOUT=1                       ;                     shift  ;;
    -pkgsrc)      CONFIG_BUILD_PKGSRC=1                         ;                     shift  ;;
    -clean)       CONFIG_BUILD_CLEAN=1                          ;                     shift  ;;
    -dry)         CONFIG_BUILD_DRY=1                            ;                     shift  ;;
    -dotag)       CONFIG_BUILD_DOTAG=1                          ;                     shift  ;;
    -local)       CONFIG_BUILD_LOCAL=1                          ;                     shift  ;;
    --help)       CONFIG_BUILD_HELP=1                           ;                     shift  ;;
    *) 	recho "not support option: $1"; CONFIG_BUILD_HELP=1;  shift  ;;
    esac
done

export SDK_CVS_USER=`echo $CVSROOT | sed 's/:/ /g' | sed 's/\@/ /g' | awk '{print $2}'`
#next 4 defines for branch
MAJOR=0
MINOR=10
BRANCH=1
TAGVER=1

case $BUILD_FOR in
    weekly)
        export CANDIDATE=$DATE
        export CVS_TAG=$SDK_TARGET_ARCH-build_$DATE
        export SDK_VERSION_ALL=$SDK_TARGET_ARCH-sdk-$DATE
        export TREE_PREFIX=msp_dev           #used by create html script
        CONFIG_BUILD_DOTAG=1
        BUILD_DIR=/build/$SDK_TARGET_ARCH/dev/weekly
        CVSTAG_DIR=/build/$SDK_TARGET_ARCH/dev/tag
        DIST_DIR=/build/$SDK_TARGET_ARCH/dev/build_result
        S200_DIR=/sdk/$SDK_TARGET_ARCH/dev/weekly/$DATE
        SDK_REMOTE_FOLDER=/home/$SDK_CVS_USER/build/jazz2/dev/tag
        ;;
    branch)
        export CANDIDATE=${BRANCH}-${TAGVER}
        export CVS_TAG=${SDK_TARGET_ARCH}-SDK-${MAJOR}_${MINOR}-${CANDIDATE}
        export SDK_VERSION_ALL=$SDK_TARGET_ARCH-sdk-${MAJOR}.${MINOR}-${CANDIDATE}
        export TREE_PREFIX=msp_rel           #used by create html script
        CONFIG_BUILD_DOTAG=1
        BUILD_DIR=/build/$SDK_TARGET_ARCH/rel
        CVSTAG_DIR=$BUILD_DIR/tag
        DIST_DIR=/build/$SDK_TARGET_ARCH/rel/build_result
        S200_DIR=/sdk/$SDK_TARGET_ARCH/rel/candidate/c2-$SDK_TARGET_ARCH-sdk-${MAJOR}.${MINOR}-${BRANCH}/${MAJOR}.${MINOR}-${CANDIDATE}
        SDK_REMOTE_FOLDER=/home/hguo/maintreebranch
        ;;
    *)   #daily, default
        export CANDIDATE=$DATE
        #export CVS_TAG=
        export SDK_VERSION_ALL=$SDK_TARGET_ARCH-sdk-$DATE
        export TREE_PREFIX=msp_dev           #used by create html script
        #CONFIG_BUILD_DOTAG=1
        BUILD_DIR=/build/$SDK_TARGET_ARCH/dev/daily
        CVSTAG_DIR=/build/$SDK_TARGET_ARCH/dev/tag
        DIST_DIR=/build/$SDK_TARGET_ARCH/dev/build_result
        S200_DIR=/sdk/$SDK_TARGET_ARCH/dev/weekly/$DATE
        SDK_REMOTE_FOLDER=/home/$SDK_CVS_USER/build/jazz2/dev/tag
    ;;
esac
if [ $CONFIG_BUILD_LOCAL ]; then
    BUILD_DIR=`pwd`
    DIST_DIR=`pwd`
fi

##  Makefile envs
#----------------------------------------------------------------------
export SDK_RESULTS_DIR=$DIST_DIR
SDK_DIR=$BUILD_DIR/sdk
PKG_DIR=$SDK_DIR/$SDK_VERSION_ALL
QT_INSTALL_DIR=$SDK_DIR/test_root/$QTINSTALL_NAME
TOOLCHAIN_PATH=$SDK_DIR/test_root/c2/daily/bin
INSTALL_DIR=/local/$DATE
PUBLISH_DIR=/local/$DATE
export SW_MEDIA_PATH=$SDK_DIR/test_root/$SDK_TARGET_ARCH-sdk/sw_media
export BUILDTIMES=1
[ "$SDK_TARGET_ARCH" = "jazz2"  ] && export SDK_TARGET_GCC_ARCH=TANGO
[ "$SDK_TARGET_ARCH" = "jazz2l" ] && export SDK_TARGET_GCC_ARCH=JAZZ2L
[ "$SDK_TARGET_ARCH" = "jazz2t" ] && export SDK_TARGET_GCC_ARCH=JAZZ2T

##  cron debug message code, these setting does not pass to Makefile
#----------------------------------------------------------------------
#export MISSION=`echo $0 | sed 's:.*/\(.*\):\1:'`
export MISSION=${0##*/}
export rlog=$HOME/rlog/rlog.$MISSION
recho()
{
    #progress echo, for debug during run as the crontab task.
    if [ ! -z "$rlog" ] ; then
    echo `date +"%Y-%m-%d %H:%M:%S"` " $@" >>$rlog.log.txt
    fi
    if [ -f $timestampslog ] ; then
    echo `date +"%Y-%m-%d %H:%M:%S"` " $@" >>$timestampslog
    fi
    echo `date +"%Y-%m-%d %H:%M:%S"` " $@"
}
recho_time_consumed()
{
    tm_b=`date +%s`
    tm_c=$(($tm_b-$1))
    tm_h=$(($tm_c/3600))
    tm_m=$(($tm_c/60))
    tm_m=$(($tm_m%60))
    tm_s=$(($tm_c%60))
    shift
    recho "$@" "$tm_c seconds / $tm_h:$tm_m:$tm_s consumed."
}
create_rebuild_envs()
{
    cat <<-EOFENV >env.sh
#!/bin/sh
#create by $BUILD_DIR/${0##*/}
#
BUILD_FOR=$BUILD_FOR                              #daily/weekly/branch, default daily
SOURCE_DIR=$SOURCE_DIR
TOOLCHAIN_PATH2ND=$TOOLCHAIN_PATH2ND
export SDK_TARGET_ARCH=$SDK_TARGET_ARCH
export SDK_QT_VERSION=$SDK_QT_VERSION
export SDK_GCC_VERSION=$SDK_GCC_VERSION
export SDK_KERNEL_VERSION=$SDK_KERNEL_VERSION
export TOOLCHAIN_PATH=$TOOLCHAIN_PATH
export QT_INSTALL_DIR=$QT_INSTALL_DIR
export MAKE_ENV="$MAKE_ENV"
export BUILD_TARGET=TARGET_LINUX_C2
export TARGET_ARCH=$SDK_TARGET_GCC_ARCH
export BUILD=RELEASE
export SW_MEDIA_PATH=$SDK_DIR/test_root/$SDK_TARGET_ARCH-sdk/sw_media
export PATH=$TOOLCHAIN_PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:\$HOME/bin

	EOFENV
    chmod 755 env.sh
    echo "create `pwd`/env.sh"
}
this_help()
{
    cat <<-EOF >&2

    Build c2 software and create package,log, upload, create webpage report, send email.
    usage: ./${0##*/} [ optional ]*
    optional:
        -dry      dry run, for debug
        -clean    total clean all the built result before start a new build
        -daily    using the source code from jazz2 sdk daily(default)
        -weekly   using the source code from jazz2 sdk weekly
        -branch   using the source code from jazz2 sdk branch
        -source full_path_name   using the source code from full_path_name

    when runs as night build crontab, please using -clean for a total build

    user manual:
    config version ---------------------------------------------
    config toolchain: gcc-4.0.3  gcc-4.3.5
    config arch     : jazz2      jazz2l     jazz2t
    config kernel   : 2.6.23     2.6.32
    config qt       : 4.5.1, 4.6.1, 4.7.0  - not implement yet
    config build action ----------------------------------------
    config checkout projects/sw/sdk, if not, using checkouted code
    config checkout source code, if not, using checkouted code
    config package source code, if not, using packaged tarballs
    config build module -modify manually
    config publish and report ----------------------------------
    config send email
    config send logs to server
    config send http web report
    config copy packages to server200
	EOF

}
cvs_processtagbydate()
{
    [ $CVS_TAG ] || return 0
    [ $CONFIG_BUILD_CHECKOUT ] || return 0
    [ -d $CVSTAG_DIR ] || return 0
    [ $CONFIG_BUILD_DOTAG ] || return 0

    recho "Tag for $BUILD_FOR build on tag=$CVS_TAG"
    recho "CVS tag start at `date`"
    pushd $CVSTAG_DIR
    #./branch.sh
    #./tag.sh sure $CVS_TAG >tag.log 2>&1
    #ssh janetliu@10.0.5.193 "cd /home/janetliu/build/jazz2/dev/tag && ./tag.sh sure REMOTE_TEST > tag.log 2>&1"
    #we setup a crontab item to do weekly tag on janetliu@10.0.5.193 on SJ time every Sunday/Tuesday 3:00am
    #just check the result via ssh/scp after a few hours start that cvs tag.
    SDK_REMOTE_SERVER=$SDK_CVS_USER@10.0.5.193
    SDK_REMOTE_LOG=recmd.all.log
    SDK_REMOTE_HEAD=recmd.head.log
    SDK_REMOTE_TAIL=recmd.tail.log
    SDK_REMOTE_HISTORY=recmd.history.log
    SDK_REMOTE_TIMEOUTHOUR=23
    ssh $SDK_REMOTE_SERVER "cd $SDK_REMOTE_FOLDER; head $SDK_REMOTE_LOG >$SDK_REMOTE_HEAD"
    scp $SDK_REMOTE_SERVER:$SDK_REMOTE_FOLDER/$SDK_REMOTE_HEAD $SDK_REMOTE_HEAD
    cat $SDK_REMOTE_HEAD
    #parse the head
    tag_done=0
    while [ $tag_done -eq 0 ]; do
        ssh $SDK_REMOTE_SERVER "cd $SDK_REMOTE_FOLDER; tail $SDK_REMOTE_LOG >$SDK_REMOTE_TAIL"
        scp $SDK_REMOTE_SERVER:$SDK_REMOTE_FOLDER/$SDK_REMOTE_TAIL $SDK_REMOTE_TAIL
        new_tail="`sed -n '$p' $SDK_REMOTE_TAIL`"
        if [ "done" == "$new_tail" ]; then
            recho "wait cvs tag done:true"
            tag_done=1
            break
        fi
        cur_hour=`date +%H`
        if [ $cur_hour -eq $SDK_REMOTE_TIMEOUTHOUR ]; then
            recho "wait cvs tag to $SDK_REMOTE_TIMEOUTHOUR:00, suppose it done"
            tag_done=1
            break
        fi
        recho "Get cvs tag tail: $new_tail"
        sleep 60
    done
    scp $SDK_REMOTE_SERVER:$SDK_REMOTE_FOLDER/$SDK_REMOTE_HISTORY .
    cat $SDK_REMOTE_HISTORY
    recho "cvs tag result: $new_tail"

    if [ $? -ne 0 ]; then
        echo "Tag failed!!!!"
        exit -1
    fi
    recho "CVS tag end at `date`"
    popd
}
addto_send()
{
    while [ $# -gt 0 ] ; do
        if [ "$SENDTO" = "" ]; then
            SENDTO=$1 ;
        else
          r=`echo $SENDTO | grep $1`
          if [ "$r" = "" ]; then
            SENDTO=$SENDTO,$1 ;
          fi
        fi
        shift
    done
    export SENDTO
}
addto_cc()
{
    while [ $# -gt 0 ] ; do
        if [ "$CCTO" = "" ]; then
            CCTO=$1 ;
        else
          r=`echo $CCTO | grep $1`
          if [ "$r" = "" ]; then
            CCTO=$CCTO,$1 ;
          fi
        fi
        shift
    done
    export CCTO
}
update_indexlog()
{
    #handle echo "Hdmi:1:$hdmilog">>$indexlog
    m=`echo $1 | sed 's,\([^:]*\).*,\1,'`
    x=`echo $1 | sed 's,[^:]*:\([^:]*\).*,\1,'`
    f=`echo $1 | sed 's,[^:]*:[^:]*:\([^:]*\).*,\1,'`
    l=`echo $f | sed 's:.*/\(.*\):\1:'`

    has=
    [ -f $2 ] && has=`grep ^$m: $2`
    if [ $has ];then
        sed -i "s,$m:.*,$1,g" $2
        recho "debug: $2 find $m and replaced $m:$x "
    else
        echo "$1" >>$2
        recho "debug: $2 not find $m, appended: $1"
    fi
}
checkadd_fail_send_list()
{
    #pickup the fail log's tail to email for a quick preview
    loglist=`cat $indexlog`
    nr_failmodule=0
    for i in $loglist ; do
        m=`echo $i | sed 's,\([^:]*\).*,\1,'`
        x=`echo $i | sed 's,[^:]*:\([^:]*\).*,\1,'`
        f=`echo $i | sed 's,[^:]*:[^:]*:\([^:]*\).*,\1,'`
        l=`echo $f | sed 's:.*/\(.*\):\1:'`
        if [ $x -ne 0 ]; then
	    nr_failmodule=$(($nr_failmodule+1))
            case $m in
            Devtools)     addto_send  saladwang@c2micro.com ;;
            Buildroot)    addto_send  saladwang@c2micro.com ;;
            SPI)          addto_send       jsun@c2micro.com ;;
            Jtag)         addto_send       jsun@c2micro.com ;;
            Uboot)        addto_send   robinlee@c2micro.com ;;
            Hdmi)         addto_send  zhenzhang@c2micro.com ;;
            C2_goodies)   addto_send   robinlee@c2micro.com ;;
            Qt)           addto_send dashanzhou@c2micro.com ;;
            Kernel)       addto_send      swine@c2micro.com ;;
            Kernel2632)   addto_send      swine@c2micro.com ;;
            Sw_media)     addto_send       weli@c2micro.com ;;
            vivante)      addto_send      llian@c2micro.com ;;
            Sw_c2apps)    addto_send dashanzhou@c2micro.com ;;
            factory_udisk)addto_send       hguo@c2micro.com ;;
            user_udisk)   addto_send       hguo@c2micro.com ;;
            *)  	  ;;
            esac
        fi
    done
    [ $nr_failmodule -gt 0 ] && addto_cc wdiao@c2micro.com
}

list_fail_url_tail()
{
    #pickup the fail log's tail to email for a quick preview
    loglist=`cat $indexlog`
    for i in $loglist ; do
        m=`echo $i | sed 's,\([^:]*\).*,\1,'`
        x=`echo $i | sed 's,[^:]*:\([^:]*\).*,\1,'`
        f=`echo $i | sed 's,[^:]*:[^:]*:\([^:]*\).*,\1,'`
        l=`echo $f | sed 's:.*/\(.*\):\1:'`
        if [ $x -ne 0 ]; then
            case $m in
            *_udisk) #jump these
                ;;
            *)
                echo $m fail :
                echo "    " "https://access.c2micro.com/~${SDK_CVS_USER}/${SDK_TARGET_ARCH}_${TREE_PREFIX}_logs/$DATE.log/$l"
                ;;
            esac
        fi
    done
    for i in $loglist ; do
        m=`echo $i | sed 's,\([^:]*\).*,\1,'`
        x=`echo $i | sed 's,[^:]*:\([^:]*\).*,\1,'`
        f=`echo $i | sed 's,[^:]*:[^:]*:\([^:]*\).*,\1,'`
        l=`echo $f | sed 's:.*/\(.*\):\1:'`
        if [ $x -ne 0 ]; then
            case $m in
            *_udisk) #jump these
                ;;
            *)
                echo
                echo $m fail , tail of $l:
                tail -n 40 $f
                ;;
            esac
        fi
    done
}
scp_upload_logs()
{
    [ ! -d $DIST_DIR/$DATE.log ] && return 1
    mkdir -p $SDK_DIR/test

    SCP_TARGET=/home/${SDK_CVS_USER}/public_html/${SDK_TARGET_ARCH}_${TREE_PREFIX}_logs/$DATE.log
    ssh  ${SDK_CVS_USER}@access.c2micro.com "mkdir -p $SCP_TARGET"
    sed -i "s,makelog.*,makelog.log," $DIST_DIR/$DATE.txt

    pushd $DIST_DIR/$DATE.log/
    if [ -f makelog.$DATE ]; then
        cp -f makelog.$DATE makelog.log
    else
        if [ -f makelog.`date +%y%m%d` ]; then
            cp -f makelog.`date +%y%m%d`  makelog.log
        fi
    fi
    for logi in *.log; do
        #some web browsers does not suport preview *.log
        if [ ! -f $logi.txt ]; then
            ln -s $logi $logi.txt
        fi
    done
    rm -f $SDK_DIR/test/logs.tar.gz
    tar czvf $SDK_DIR/test/logs.tar.gz  *
    scp $SDK_DIR/test/logs.tar.gz  ${SDK_CVS_USER}@access.c2micro.com:$SCP_TARGET/
    ssh  ${SDK_CVS_USER}@access.c2micro.com "cd $SCP_TARGET; tar xzf logs.tar.gz; unix2dos * ; rm logs.tar.gz"
    popd
}
update_makefile_envs()
{
if [ $CONFIG_BUILD_CHECKOUT  ]; then
    MAKE_ENV="CANDIDATE=$CANDIDATE MAJOR=${MAJOR} MINOR=${MINOR} SDK_VERSION_ALL=${SDK_VERSION_ALL} \
	CVS_TAG=$CVS_TAG \
	TOOLCHAIN_PATH=$TOOLCHAIN_PATH SW_MEDIA_PATH=$SW_MEDIA_PATH \
    	QT_INSTALL_DIR=${QT_INSTALL_DIR} "
else
    CHECKOUT=echo
    UPDATE=echo
    MAKE_ENV="CANDIDATE=$CANDIDATE MAJOR=${MAJOR} MINOR=${MINOR} SDK_VERSION_ALL=${SDK_VERSION_ALL} \
	CVS_TAG=$CVS_TAG CHECKOUT=$CHECKOUT UPDATE=$UPDATE \
	TOOLCHAIN_PATH=$TOOLCHAIN_PATH SW_MEDIA_PATH=$SW_MEDIA_PATH \
    	QT_INSTALL_DIR=${QT_INSTALL_DIR} "
fi
}
config_debug()
{
if [ $CONFIG_BUILD_DRY          ]; then recho "enable  * CONFIG_BUILD_DRY         "; else recho "disable   CONFIG_BUILD_DRY         ";fi
if [ $CONFIG_BUILD_HELP         ]; then recho "enable  * CONFIG_BUILD_HELP        "; else recho "disable   CONFIG_BUILD_HELP        ";fi
if [ $CONFIG_BUILD_LOCAL        ]; then recho "enable  * CONFIG_BUILD_LOCAL       "; else recho "disable   CONFIG_BUILD_LOCAL       ";fi
if [ $CONFIG_BUILD_DOTAG        ]; then recho "enable  * CONFIG_BUILD_DOTAG       "; else recho "disable   CONFIG_BUILD_DOTAG       ";fi
if [ $CONFIG_BUILD_CLEAN        ]; then recho "enable  * CONFIG_BUILD_CLEAN       "; else recho "disable   CONFIG_BUILD_CLEAN       ";fi
if [ $CONFIG_BUILD_SDK          ]; then recho "enable  * CONFIG_BUILD_SDK         "; else recho "disable   CONFIG_BUILD_SDK         ";fi
if [ $CONFIG_BUILD_CHECKOUT     ]; then recho "enable  * CONFIG_BUILD_CHECKOUT    "; else recho "disable   CONFIG_BUILD_CHECKOUT    ";fi
if [ $CONFIG_BUILD_PKGSRC       ]; then recho "enable  * CONFIG_BUILD_PKGSRC      "; else recho "disable   CONFIG_BUILD_PKGSRC      ";fi
if [ $CONFIG_BUILD_PKGBIN       ]; then recho "enable  * CONFIG_BUILD_PKGBIN      "; else recho "disable   CONFIG_BUILD_PKGBIN      ";fi
if [ $CONFIG_BUILD_DEVTOOLS     ]; then recho "enable  * CONFIG_BUILD_DEVTOOLS    "; else recho "disable   CONFIG_BUILD_DEVTOOLS    ";fi
if [ $CONFIG_BUILD_SPI          ]; then recho "enable  * CONFIG_BUILD_SPI         "; else recho "disable   CONFIG_BUILD_SPI         ";fi
if [ $CONFIG_BUILD_DIAG         ]; then recho "enable  * CONFIG_BUILD_DIAG        "; else recho "disable   CONFIG_BUILD_DIAG        ";fi
if [ $CONFIG_BUILD_JTAG         ]; then recho "enable  * CONFIG_BUILD_JTAG        "; else recho "disable   CONFIG_BUILD_JTAG        ";fi
if [ $CONFIG_BUILD_UBOOT        ]; then recho "enable  * CONFIG_BUILD_UBOOT       "; else recho "disable   CONFIG_BUILD_UBOOT       ";fi
if [ $CONFIG_BUILD_C2GOODIES    ]; then recho "enable  * CONFIG_BUILD_C2GOODIES   "; else recho "disable   CONFIG_BUILD_C2GOODIES   ";fi
if [ $CONFIG_BUILD_QT           ]; then recho "enable  * CONFIG_BUILD_QT          "; else recho "disable   CONFIG_BUILD_QT          ";fi
if [ $CONFIG_BUILD_DOC          ]; then recho "enable  * CONFIG_BUILD_DOC         "; else recho "disable   CONFIG_BUILD_DOC         ";fi
if [ $CONFIG_BUILD_KERNEL       ]; then recho "enable  * CONFIG_BUILD_KERNEL      "; else recho "disable   CONFIG_BUILD_KERNEL      ";fi
if [ $CONFIG_BUILD_HDMI         ]; then recho "enable  * CONFIG_BUILD_HDMI        "; else recho "disable   CONFIG_BUILD_HDMI        ";fi
if [ $CONFIG_BUILD_SWMEDIA      ]; then recho "enable  * CONFIG_BUILD_SWMEDIA     "; else recho "disable   CONFIG_BUILD_SWMEDIA     ";fi
if [ $CONFIG_BUILD_VIVANTE      ]; then recho "enable  * CONFIG_BUILD_VIVANTE     "; else recho "disable   CONFIG_BUILD_VIVANTE     ";fi
if [ $CONFIG_BUILD_C2APPS       ]; then recho "enable  * CONFIG_BUILD_C2APPS      "; else recho "disable   CONFIG_BUILD_C2APPS      ";fi
if [ $CONFIG_BUILD_FACUDISK     ]; then recho "enable  * CONFIG_BUILD_FACUDISK    "; else recho "disable   CONFIG_BUILD_FACUDISK    ";fi
if [ $CONFIG_BUILD_USRUDISK     ]; then recho "enable  * CONFIG_BUILD_USRUDISK    "; else recho "disable   CONFIG_BUILD_USRUDISK    ";fi
if [ $CONFIG_BUILD_PUBLISH      ]; then recho "enable  * CONFIG_BUILD_PUBLISH     "; else recho "disable   CONFIG_BUILD_PUBLISH     ";fi
if [ $CONFIG_BUILD_PUBLISHLOG   ]; then recho "enable  * CONFIG_BUILD_PUBLISHLOG  "; else recho "disable   CONFIG_BUILD_PUBLISHLOG  ";fi
if [ $CONFIG_BUILD_PUBLISHHTML  ]; then recho "enable  * CONFIG_BUILD_PUBLISHHTML "; else recho "disable   CONFIG_BUILD_PUBLISHHTML ";fi
if [ $CONFIG_BUILD_PUBLISHEMAIL ]; then recho "enable  * CONFIG_BUILD_PUBLISHEMAIL"; else recho "disable   CONFIG_BUILD_PUBLISHEMAIL";fi
}
##  Build script used settings, these setting does not pass to Makefile
#----------------------------------------------------------------------

#this script used
HAVE_ERROR=0
RETRY=10

# Define location of build_result
INSTALL_DIR=$DIST_DIR/$DATE
LOG_DIR=$DIST_DIR/$DATE.log
indexlog=$DIST_DIR/$DATE.txt
devtoolslog=$LOG_DIR/devtools.log
buildrootlog=$LOG_DIR/makelog.log
kernellog=$LOG_DIR/kernle.log
kernelnandlog=$LOG_DIR/kernlenand.log
kernel2632log=$LOG_DIR/kernle2632.log
hdmilog=$LOG_DIR/hdmi.log
spilog=$LOG_DIR/spi.log
jtaglog=$LOG_DIR/jtag.log
diaglog=$LOG_DIR/diag.log
ubootlog=$LOG_DIR/uboot.log
swmedialog=$LOG_DIR/swmedia.log
qtlog=$LOG_DIR/qt.log
swc2appslog=$LOG_DIR/swc2apps.log
c2goodieslog=$LOG_DIR/c2goodies.log
pvrtestdemolog=$LOG_DIR/pvrtestdemo.log
vivantelog=$LOG_DIR/vivante.log
factoryudisklog=$LOG_DIR/factoryudisk.log
userudisklog=$LOG_DIR/userudisk.log
timestampslog=$LOG_DIR/timestamps.log

#CONFIG_BUILD_DRY=1
#CONFIG_BUILD_HELP=1
#CONFIG_BUILD_LOCAL=1
#CONFIG_BUILD_DOTAG=1
CONFIG_BUILD_CLEAN=1
CONFIG_BUILD_SDK=1
CONFIG_BUILD_CHECKOUT=1
CONFIG_BUILD_PKGSRC=1
CONFIG_BUILD_PKGBIN=1
CONFIG_BUILD_DEVTOOLS=1
CONFIG_BUILD_SPI=1
CONFIG_BUILD_DIAG=1
CONFIG_BUILD_JTAG=1
CONFIG_BUILD_UBOOT=1
CONFIG_BUILD_C2GOODIES=1
CONFIG_BUILD_QT=1
CONFIG_BUILD_DOC=1
CONFIG_BUILD_KERNEL=1
CONFIG_BUILD_HDMI=1
CONFIG_BUILD_SWMEDIA=1
CONFIG_BUILD_VIVANTE=1
CONFIG_BUILD_C2APPS=1
CONFIG_BUILD_FACUDISK=1
CONFIG_BUILD_USRUDISK=1
CONFIG_BUILD_PUBLISH=1
CONFIG_BUILD_PUBLISHLOG=1
CONFIG_BUILD_PUBLISHHTML=1
CONFIG_BUILD_PUBLISHEMAIL=1

if [ ! -f $SDK_DIR/Makefile ] && [ ! -f $SDK_DIR/vertical/Makefile.pvr ]; then
    CONFIG_BUILD_SDK=1
fi
if [ "$TOOLCHAIN_PATH" = "$SDK_DIR/test_root/c2/daily/bin" ] && [ ! -d $SDK_DIR/test_root/c2 ]; then
    CONFIG_BUILD_DEVTOOLS=1
fi

VERSION=${MAJOR}_${MINOR}
update_makefile_envs

if [ $CONFIG_BUILD_HELP       ]; then
    this_help
    exit 0
fi

##  Go !
#----------------------------------------------------------------------
mkdir -p $HOME/rlog
echo `date +"%Y-%m-%d %H:%M:%S"` "pid=$$ $0 $@" >>$rlog.log.txt
date >>$rlog.log.txt
env  >>$rlog.log.txt
tm_a=`date +%s`
recho MAKE_ENV=$MAKE_ENV
config_debug
env

mkdir -p $BUILD_DIR    $SDK_DIR
mkdir -p $INSTALL_DIR  $LOG_DIR
[ -h $DIST_DIR/l ] && rm $DIST_DIR/l
[ -h $DIST_DIR/r ] && rm $DIST_DIR/r
[ -h $DIST_DIR/i ] && rm $DIST_DIR/i
ln -s $DIST_DIR/$DATE      $DIST_DIR/i
ln -s $DIST_DIR/$DATE.log  $DIST_DIR/l
ln -s $DIST_DIR/$DATE.txt  $DIST_DIR/r

pushd $BUILD_DIR
create_rebuild_envs
if [ $CONFIG_BUILD_DRY       ]; then
    exit 0
fi

if [ ! -d sdk/CVS ]; then
    recho "Checkout projects/sw/sdk, tag=$CVS_TAG for the first time"
    CHECKOUT_OPTION=
    [ "$CVS_TAG" != "" ] && CHECKOUT_OPTION="-r $CVS_TAG"
    cvs -q co -A -d sdk $CHECKOUT_OPTION projects/sw/sdk
    recho "Checkout projects/sw/sdk, tag=$CVS_TAG done"
fi

cvs_processtagbydate

recho "Start new mission"
pushd $SDK_DIR
if [ $CONFIG_BUILD_SDK       ]; then
    recho "Update projects/sw/sdk, tag=$CVS_TAG"
    CHECKOUT_OPTION=
    [ "$CVS_TAG" != "" ] && CHECKOUT_OPTION="-r $CVS_TAG"
    cvs update -CAPd $CHECKOUT_OPTION
    recho "Update projects/sw/sdk, tag=$CVS_TAG done"
fi

[ -d source ] || ln -s $SOURCE_DIR source

if [ $CONFIG_BUILD_CLEAN ]; then
    recho "make all things clean"
    make $MAKE_ENV clean
    rm -rf $PKG_DIR temp test_root test
    rm -f $indexlog
fi
mkdir -p $PKG_DIR temp test_root test  #some Makefile target is stupid for make -p these folders.

build_packages()
{
    if [ $# -lt 4 ]; then
        recho "usage : build_packages [Makefile] [source] [binary] [log file]"
        return -1
    fi
    CO_ERR=0
    recho "build_package $@ "

    tm_pkg=`date +%s`
    recho "SDK build $2"
    echo "Use c2 tools: $TOOLCHAIN_PATH" >> $4
    while [ $CO_ERR -lt $RETRY ] && [ "$2" != "nop" ] &&  [ $CONFIG_BUILD_PKGSRC ]
    do
        make -f $1 $MAKE_ENV $2 >> $4 2>&1
        if [ $? -eq 0 ]; then
            break;
        fi
        let "CO_ERR++"
        echo "Error : cvs checkout failed, retry = $CO_ERR" >> $4
    done
    if [ $CO_ERR -eq $RETRY ]; then
        recho "CVS make $2 $CO_ERR times. fail"
        let "HAVE_ERROR++"
        return -1
    fi
    recho_time_consumed $tm_pkg "SDK build $2 success"

    tm_pkg=`date +%s`
    recho "SDK build $3"
    if [ "$3" != "nop" ] &&  [ $CONFIG_BUILD_PKGBIN ]; then
    make -f $1 $MAKE_ENV $3 >> $4 2>&1
    if [ $? -ne 0 ]; then
        recho "SDK build $3 fail at `date`"
        let "HAVE_ERROR++"
        return -1
    fi
    fi
    recho_time_consumed $tm_pkg "SDK build $3 success"

    return 0
}

SSHCMD=echo
if [ $CONFIG_BUILD_DEVTOOLS ]; then
        # the actual devtools log is buildroot log
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/devtools" > $devtoolslog
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/sdk" >> $devtoolslog
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/strace" >> $devtoolslog
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/oprofile" >> $devtoolslog
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/directfb" >> $devtoolslog
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/cmd" >> $devtoolslog
        build_packages "Makefile" "devtools-src" "devtools-src-test devtools-bin" "$devtoolslog"
        sedmakelog=`grep "Build output logged to" $devtoolslog | sed 's,Build output logged to \(.*\),\1,g'`
        cp -f $sedmakelog $buildrootlog
        if [ $? -ne 0 ]; then
            update_indexlog "Devtools:1:$devtoolslog" $indexlog
            update_indexlog "Buildroot:1:$buildrootlog" $indexlog
        else
            update_indexlog "Devtools:0:$devtoolslog" $indexlog
            update_indexlog "Buildroot:0:$buildrootlog" $indexlog
        fi
        if [ $HAVE_ERROR -ne 0 ] ; then  #toolchain not available, try alt to build more
            TOOLCHAIN_PATH=$TOOLCHAIN_PATH2ND
            update_makefile_envs
        fi
fi

if [ $CONFIG_BUILD_SPI ]; then
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/jtag"  > $spilog
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/prom" >> $spilog
        build_packages "Makefile" "spi-src" "spi-bin" "$spilog"
        if [ $? -ne 0 ]; then
            update_indexlog "SPI:1:$spilog" $indexlog
        else
            update_indexlog "SPI:0:$spilog" $indexlog
        fi
fi

if [ $CONFIG_BUILD_DIAG ]; then
        build_packages "Makefile" "diag-src" "diag-bin" "$diaglog"
        if [ $? -ne 0 ]; then
            update_indexlog "diag:1:$spilog" $indexlog
        else
            update_indexlog "diag:0:$spilog" $indexlog
        fi
fi

if [ $CONFIG_BUILD_JTAG ]; then
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/jtag"  > $jtaglog
        build_packages "Makefile" "jtag-src" "jtag-bin" "$jtaglog"
        if [ $? -ne 0 ]; then
            update_indexlog "Jtag:1:$jtaglog" $indexlog
        else
            update_indexlog "Jtag:0:$jtaglog" $indexlog
        fi
fi

if [ $CONFIG_BUILD_UBOOT ]; then
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/prom" >> $ubootlog
        build_packages "Makefile" "u-boot-src" "u-boot-bin" "$ubootlog"
        if [ $? -ne 0 ]; then
            update_indexlog "Uboot:1:$ubootlog" $indexlog
        else
            update_indexlog "Uboot:0:$ubootlog" $indexlog
        fi
fi

if [ $CONFIG_BUILD_C2GOODIES ]; then
        build_packages "Makefile" "c2_goodies-src" "c2_goodies-bin" "$c2goodieslog"
        if [ $? -ne 0 ]; then
            update_indexlog "C2_goodies:1:$c2goodieslog" $indexlog
        else
            update_indexlog "C2_goodies:0:$c2goodieslog" $indexlog
        fi
fi

if [ $CONFIG_BUILD_KERNEL ]; then
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/kernel" > $kernellog

	if [ "$SDK_TARGET_ARCH" = "jazz2l"  ]; then
            build_packages "vertical/Makefile.pvr" "kernel-src" "kernel-bin-jazz2l" "$kernelnandlog"
            if [ $? -ne 0 ]; then
                update_indexlog "Kernelnand:1:$kernelnandlog" $indexlog
            else
                update_indexlog "Kernelnand:0:$kernelnandlog" $indexlog
            fi
            build_packages "vertical/Makefile.pvr" "nop" "kernel-bin" "$kernellog"
	    if [ $? -ne 0 ]; then
	        update_indexlog "Kernel:1:$kernellog" $indexlog
	    else
	        update_indexlog "Kernel:0:$kernellog" $indexlog
	    fi
	fi

        ##---------------------------------------------------------------------------------------
	if [ "$SDK_TARGET_ARCH" = "jazz2"  ]; then
            build_packages "vertical/Makefile.pvr" "kernel-src" "kernel-bin" "$kernellog"
            if [ $? -ne 0 ]; then
                update_indexlog "Kernel:1:$kernellog" $indexlog
            else
                update_indexlog "Kernel:0:$kernellog" $indexlog
            fi
            build_packages "vertical/Makefile.pvr" "nop" "kernel-nand-bin" "$kernelnandlog"
            if [ $? -ne 0 ]; then
                update_indexlog "Kernelnand:1:$kernelnandlog" $indexlog
            else
                update_indexlog "Kernelnand:0:$kernelnandlog" $indexlog
            fi
	    build_packages "vertical/Makefile.pvr" "kernel-src-2632" "kernel-bin-2632" "$kernel2632log"
	    if [ $? -ne 0 ]; then
	        update_indexlog "Kernel2632:1:$kernel2632log" $indexlog
	    else
	        update_indexlog "Kernel2632:0:$kernel2632log" $indexlog
	    fi
	fi
fi

if [ $CONFIG_BUILD_HDMI ]; then
        build_packages "vertical/Makefile.pvr" "hdmi-jazz2-src" "hdmi-jazz2-bin" "$hdmilog"
        if [ $? -ne 0 ]; then
            update_indexlog "Hdmi:1:$hdmilog" $indexlog
        else
            update_indexlog "Hdmi:0:$hdmilog" $indexlog
        fi
fi

if [ $CONFIG_BUILD_SWMEDIA ]; then
        # if sw_media compile failed, exit
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/media" > $swmedialog
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/mx" >> $swmedialog
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/build" >> $swmedialog
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/csim" >> $swmedialog
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/application" >> $swmedialog
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/intrinsics" >> $swmedialog
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/media" >> $swmedialog
        build_packages "vertical/Makefile.pvr" "sw_media-src" "sw_media-bin" "$swmedialog"
        if [ $? -ne 0 ]; then
            update_indexlog "Sw_media:1:$swmedialog" $indexlog
        else
            update_indexlog "Sw_media:0:$swmedialog" $indexlog
        fi
fi

if [ $CONFIG_BUILD_VIVANTE ]; then
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/bsp" > $vivantelog
        build_packages "vertical/Makefile.pvr" "vivante-src" "vivante-bin" "$vivantelog"
        if [ $? -ne 0 ]; then
            update_indexlog "vivante:1:$vivantelog" $indexlog
        else
            update_indexlog "vivante:0:$vivantelog" $indexlog
        fi
fi

if [ $CONFIG_BUILD_QT ]; then
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/Qt/qt-everywhere-opensource-src-4.6.1" >> $qtlog
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/Qt/qt-everywhere-opensource-src-4.7.0" >> $qtlog
        build_packages "Makefile" "qt-src" "qt-bin" "$qtlog"
        if [ $? -ne 0 ]; then
            update_indexlog "Qt:1:$qtlog" $indexlog
        else
            update_indexlog "Qt:0:$qtlog" $indexlog
        fi
fi

if [ $CONFIG_BUILD_C2APPS ]; then
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/c2apps" > $swc2appslog
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/c2apps" > $swc2appslog
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/cmd/lirc" >> $swc2appslog
        build_packages "vertical/Makefile.pvr" "sw_c2apps-src" "demo-bin" "$swc2appslog"
        if [ $? -ne 0 ]; then
            update_indexlog "Sw_c2apps:1:$swc2appslog" $indexlog
        else
            update_indexlog "Sw_c2apps:0:$swc2appslog" $indexlog
        fi
fi

if [ $CONFIG_BUILD_FACUDISK ]; then
        if [ $HAVE_ERROR -eq 0 ]; then
        make -f Makefile $MAKE_ENV  factory-udisk >> $factoryudisklog 2>&1
        if [ $? -ne 0 ]; then
            update_indexlog "factory_udisk:1:$factoryudisklog" $indexlog
        else
            update_indexlog "factory_udisk:0:$factoryudisklog" $indexlog
        fi
        fi
fi

if [ $CONFIG_BUILD_USRUDISK ]; then
        if [ $HAVE_ERROR -eq 0 ]; then
        make -f Makefile $MAKE_ENV  user-udisk >> $userudisklog 2>&1
        if [ $? -ne 0 ]; then
            update_indexlog "user_udisk:1:$userudisklog" $indexlog
        else
            update_indexlog "user_udisk:0:$userudisklog" $indexlog
        fi
        fi
fi

if [ $CONFIG_BUILD_DOC ]; then
        make -f vertical/Makefile.pvr $MAKE_ENV doc
fi

recho "Build result have $HAVE_ERROR errors"
recho_time_consumed $tm_a

if [ $CONFIG_BUILD_PUBLISHLOG ]; then
    scp_upload_logs
fi
if [ $CONFIG_BUILD_PUBLISH ]; then
    #copy build environment to package for other developer's debug
    cp -t $PKG_DIR Makefile vertical/Makefile.pvr
    [ -f ../${0##*/} ] && cp -t $PKG_DIR ../${0##*/}
    [ -f ../env.sh   ] && cp -t $PKG_DIR ../env.sh
    #copy build packages to server
    if [ $HAVE_ERROR -ne 0 ] ; then
        echo "build fail, see rlog*.txt for detail" >$PKG_DIR/BUILD_FAIL
        cp $indexlog $PKG_DIR/
        cp $rlog.log.txt $PKG_DIR/
        cp $SDK_DIR/test/logs.tar.gz $PKG_DIR/
    else
        rm -f $PKG_DIR/BUILD_FAIL
    fi
    if [ $HAVE_ERROR -eq 0 ] ; then
        ssh ${SDK_CVS_USER}@10.16.13.200     "mkdir -p $S200_DIR"
        scp -r $PKG_DIR/* ${SDK_CVS_USER}@10.16.13.200:$S200_DIR/
    fi
fi
popd   #pushd $SDK_DIR
if [ $CONFIG_BUILD_PUBLISHHTML ]; then
    #create and send report
    case $BUILD_FOR in
        branch)
            HTML_REPORT=${SDK_TARGET_ARCH}_${TREE_PREFIX}_sdk_branch.html
            ;;
        *)   #daily and weekly
            HTML_REPORT=${SDK_TARGET_ARCH}_${TREE_PREFIX}_sdk_daily.html
            ;;
    esac
    #the cgi need 3 variable pre-defined. it need a tail '/' in SDK_RESULTS_DIR, otherwise, we need fix the dev_logs//100829.log
    #SDK_RESULTS_DIR=$DIST_DIR/ SDK_CVS_USER=janetliu SDK_TARGET_ARCH=$SDK_TARGET_ARCH
    SDK_RESULTS_DIR="$DIST_DIR/"  ./html_generate.cgi  >$DIST_DIR/$HTML_REPORT
    #fix: // in url like:  href='https://access.c2micro.com/jazz2_msp_dev_logs//100829.log
    #sed -i 's:_logs//1:_logs/1:g' $DIST_DIR/$HTML_REPORT
    [ $BUILD_FOR == "branch" ] && sed -i 's:SDK Daily Build Results:SDK Branch Build Results:g' $DIST_DIR/$HTML_REPORT
    scp $DIST_DIR/$HTML_REPORT  ${SDK_CVS_USER}@access.c2micro.com:/home/${SDK_CVS_USER}/public_html/
fi
if [ $CONFIG_BUILD_PUBLISHEMAIL ]; then
    addto_send mingliu@c2micro.com yanyantong@c2micro.com
    checkadd_fail_send_list
    addto_cc jsun@c2micro.com weli@c2micro.com mxia@c2micro.com sliu@c2micro.com slu@c2micro.com
    addto_cc hguo@c2micro.com janetliu@c2micro.com
    mail_title="$SDK_TARGET_ARCH gcc-$SDK_GCC_VERSION kernel-$SDK_KERNEL_VERSION qt-$SDK_QT_VERSION $BUILD_FOR build report: $HAVE_ERROR errors"
    (
	echo "$mail_title"
        echo "Click link to watch status: "
        echo "https://access.c2micro.com/~${SDK_CVS_USER}/$HTML_REPORT"
        if [ $HAVE_ERROR -eq 0 ] ; then
            echo "a local build copied to: 10.16.13.200:$S200_DIR/"
        else
            echo "Please check build error and fix it in ***TODAY***"
        fi
        list_fail_url_tail
        tail -2 $rlog.log.txt
    ) 2>&1 | mail -s"$mail_title" -c $CCTO $SENDTO
fi
# cp sdk_build.sh ~/sdk/sdk_build.sh ; pushd ~/sdk; autosync sdk_build.sh ;popd
