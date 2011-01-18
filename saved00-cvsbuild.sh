#!/bin/sh

. ~/.bash_profile

## Global and ***simple*** defines used by this, Makefile, cgi scripts
#----------------------------------------------------------------------
export DATE=`date +%y%m%d`
export SDK_TARGET_ARCH=jazz2l
SOURCE_DIR=/build/jazz2/dev/daily/sdk/source
[ "${0##*/}" == "jazz2"  ] && export SDK_TARGET_ARCH=${0##*/}
[ "${0##*/}" == "jazz2l" ] && export SDK_TARGET_ARCH=${0##*/}
[ "${0##*/}" == "jazz2t" ] && export SDK_TARGET_ARCH=${0##*/}
[ "${0##*/}" == "jazz1"  ] && export SDK_TARGET_ARCH=${0##*/}
[ "${0##*/}" == "jazzb"  ] && export SDK_TARGET_ARCH=${0##*/}

##  Get command line args, override all the configured settings.
#----------------------------------------------------------------------
while [ $# -gt 0 ] ; do
    case $1 in
    -daily)       SOURCE_DIR=/build/jazz2/dev/daily/sdk/source  ;  shift  ;;
    -weekly)      SOURCE_DIR=/build/jazz2/dev/weekly/sdk/source ;  shift  ;;
    -source)      SOURCE_DIR=$2                                 ;  shift 2;;
    -tag)         export CVS_TAG=$2                             ;  shift 2;;
    -arch)        export SDK_TARGET_ARCH=$2                     ;  shift 2;;
    -date)        export DATE=$2                                ;  shift 2;;
    -checkout)    CONFIG_BUILD_CHECKOUT=1                       ;  shift  ;;
    -pkgsrc)      CONFIG_BUILD_PKGSRC=1                         ;  shift  ;;
    -clean)       CONFIG_BUILD_CLEAN=1                          ;  shift  ;;
    -dry)         CONFIG_BUILD_DRY=1                            ;  shift  ;;
    -local)       CONFIG_BUILD_LOCAL=1                          ;  shift  ;;
    --help)       CONFIG_BUILD_HELP=1                           ;  shift  ;;
    *) 	recho "not support option: $1"; CONFIG_BUILD_HELP=1;  shift  ;;
    esac
done
if [ $CONFIG_BUILD_LOCAL ]; then
BUILD_DIR=`pwd`
DIST_DIR=`pwd`
else
BUILD_DIR=/build/$SDK_TARGET_ARCH/dev/daily
DIST_DIR=/build/$SDK_TARGET_ARCH/dev/build_result
fi
export SDK_RESULTS_DIR=$DIST_DIR
export SDK_VERSION_ALL=$SDK_TARGET_ARCH-sdk-$DATE
SDK_DIR=$BUILD_DIR/sdk
PKG_DIR=$SDK_DIR/$SDK_VERSION_ALL

##  cron debug message code, these setting does not pass to Makefile
#----------------------------------------------------------------------
#export MISSION=`echo $0 | sed 's:.*/\(.*\):\1:'`
export MISSION=${0##*/}
export rlog=$HOME/rlog/rlog.$MISSION
recho()
{
    #progress echo, for debug during run as the crontab task.
    if [ ! -z "$rlog" ] ; then
    echo -en `date +"%Y-%m-%d %H:%M:%S"` " " >>$rlog.log.txt
    echo "$@" >>$rlog.log.txt
    fi
    if [ -f $timestampslog ] ; then
    echo -en `date +"%Y-%m-%d %H:%M:%S"` " " >>$timestampslog
    echo "$@" >>$timestampslog
    fi
    echo "$@"
    [ "`whoami`" != "hguo" ] && [ -w /home/hguo/rlog ] && cp -f $rlog* /home/hguo/rlog/
}
recho_time_consumed()
{
    tm_b=`date +%s`
    tm_c=$(($tm_b-$tm_a))
    tm_h=$(($tm_c/3600))
    tm_m=$(($tm_c/60))
    tm_m=$(($tm_m%60))
    tm_s=$(($tm_c%60))
    recho "$@" "$tm_c seconds / $tm_h:$tm_m:$tm_s consumed."
}
create_rebuild_envs()
{
    cat <<-EOFENV >env.sh
#!/bin/sh
export SDK_TARGET_ARCH=$SDK_TARGET_ARCH
export TOOLCHAIN_PATH=$TOOLCHAIN_PATH
export QT_INSTALL_DIR=$SDK_DIR/test_root/QtopiaCore-4.6.1-generic
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
        -source full_path_name   using the source code from full_path_name

    when runs as night build crontab, please using -clean for a total build

	EOF

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
        recho "debug: find $m and replaced $m:$x "
    else
        echo "$1" >>$2
        recho "debug: not find $m, appended: $1"
    fi
}
checkadd_fail_send_list()
{
    #pickup the fail log's tail to email for a quick preview
    loglist=`cat $indexlog`
    nr_send=0
    for i in $loglist ; do
        m=`echo $i | sed 's,\([^:]*\).*,\1,'`
        x=`echo $i | sed 's,[^:]*:\([^:]*\).*,\1,'`
        f=`echo $i | sed 's,[^:]*:[^:]*:\([^:]*\).*,\1,'`
        l=`echo $f | sed 's:.*/\(.*\):\1:'`
	nr_send=$(($nr_send+1))
        if [ $x -ne 0 ]; then
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
            *)  	  nr_send=$(($nr_send-1));
            esac
        fi
    done
    [ $nr_send -gt 0 ] && addto_cc wdiao@c2micro.com
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
        mv makelog.$DATE makelog.log
    else
        if [ -f makelog.`date +%y%m%d` ]; then
            mv makelog.`date +%y%m%d`  makelog.log
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
config_debug()
{
if [ $CONFIG_BUILD_DRY       ]; then recho "enable   * CONFIG_BUILD_DRY      "; else recho "disable    CONFIG_BUILD_DRY      ";fi
if [ $CONFIG_BUILD_HELP      ]; then recho "enable   * CONFIG_BUILD_HELP     "; else recho "disable    CONFIG_BUILD_HELP     ";fi
if [ $CONFIG_BUILD_LOCAL     ]; then recho "enable   * CONFIG_BUILD_LOCAL    "; else recho "disable    CONFIG_BUILD_LOCAL    ";fi
if [ $CONFIG_BUILD_CLEAN     ]; then recho "enable   * CONFIG_BUILD_CLEAN    "; else recho "disable    CONFIG_BUILD_CLEAN    ";fi
if [ $CONFIG_BUILD_SDK       ]; then recho "enable   * CONFIG_BUILD_SDK      "; else recho "disable    CONFIG_BUILD_SDK      ";fi
if [ $CONFIG_BUILD_CHECKOUT  ]; then recho "enable   * CONFIG_BUILD_CHECKOUT "; else recho "disable    CONFIG_BUILD_CHECKOUT ";fi
if [ $CONFIG_BUILD_PKGSRC    ]; then recho "enable   * CONFIG_BUILD_PKGSRC   "; else recho "disable    CONFIG_BUILD_PKGSRC   ";fi
if [ $CONFIG_BUILD_DEVTOOLS  ]; then recho "enable   * CONFIG_BUILD_DEVTOOLS "; else recho "disable    CONFIG_BUILD_DEVTOOLS ";fi
if [ $CONFIG_BUILD_SPI       ]; then recho "enable   * CONFIG_BUILD_SPI      "; else recho "disable    CONFIG_BUILD_SPI      ";fi
if [ $CONFIG_BUILD_JTAG      ]; then recho "enable   * CONFIG_BUILD_JTAG     "; else recho "disable    CONFIG_BUILD_JTAG     ";fi
if [ $CONFIG_BUILD_UBOOT     ]; then recho "enable   * CONFIG_BUILD_UBOOT    "; else recho "disable    CONFIG_BUILD_UBOOT    ";fi
if [ $CONFIG_BUILD_C2GOODIES ]; then recho "enable   * CONFIG_BUILD_C2GOODIES"; else recho "disable    CONFIG_BUILD_C2GOODIES";fi
if [ $CONFIG_BUILD_QT        ]; then recho "enable   * CONFIG_BUILD_QT       "; else recho "disable    CONFIG_BUILD_QT       ";fi
if [ $CONFIG_BUILD_DOC       ]; then recho "enable   * CONFIG_BUILD_DOC      "; else recho "disable    CONFIG_BUILD_DOC      ";fi
if [ $CONFIG_BUILD_KERNEL    ]; then recho "enable   * CONFIG_BUILD_KERNEL   "; else recho "disable    CONFIG_BUILD_KERNEL   ";fi
if [ $CONFIG_BUILD_HDMI      ]; then recho "enable   * CONFIG_BUILD_HDMI     "; else recho "disable    CONFIG_BUILD_HDMI     ";fi
if [ $CONFIG_BUILD_SWMEDIA   ]; then recho "enable   * CONFIG_BUILD_SWMEDIA  "; else recho "disable    CONFIG_BUILD_SWMEDIA  ";fi
if [ $CONFIG_BUILD_VIVANTE   ]; then recho "enable   * CONFIG_BUILD_VIVANTE  "; else recho "disable    CONFIG_BUILD_VIVANTE  ";fi
if [ $CONFIG_BUILD_C2APPS    ]; then recho "enable   * CONFIG_BUILD_C2APPS   "; else recho "disable    CONFIG_BUILD_C2APPS   ";fi
if [ $CONFIG_BUILD_FACUDISK  ]; then recho "enable   * CONFIG_BUILD_FACUDISK "; else recho "disable    CONFIG_BUILD_FACUDISK ";fi
if [ $CONFIG_BUILD_USRUDISK  ]; then recho "enable   * CONFIG_BUILD_USRUDISK "; else recho "disable    CONFIG_BUILD_USRUDISK ";fi
if [ $CONFIG_BUILD_PUBLISH   ]; then recho "enable   * CONFIG_BUILD_PUBLISH  "; else recho "disable    CONFIG_BUILD_PUBLISH  ";fi
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
buildrootlog=$LOG_DIR/makelog.$DATE
kernellog=$LOG_DIR/kernle.log
kernelnandlog=$LOG_DIR/kernlenand.log
kernel2632log=$LOG_DIR/kernle2632.log
hdmilog=$LOG_DIR/hdmi.log
spilog=$LOG_DIR/spi.log
jtaglog=$LOG_DIR/jtag.log
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

##  Makefile envs
#----------------------------------------------------------------------
export TREE_PREFIX=msp_dev           #used by create html script
[ "$SDK_TARGET_ARCH" = "jazz2"  ] && export SDK_TARGET_GCC_ARCH=TANGO
[ "$SDK_TARGET_ARCH" = "jazz2l" ] && export SDK_TARGET_GCC_ARCH=JAZZ2L
export SDK_KERNEL_VERSION=2.6.23
export SDK_CVS_USER=`echo $CVSROOT | sed 's/:/ /g' | sed 's/\@/ /g' | awk '{print $2}'`
export BUILDTIMES=1

#settings in "Makefile" can be overrided by set them here and pass to "ENV"
#takes no effect if not pass to "ENV", even using "export"
[ -z $CVS_TAG         ] && export CVS_TAG=""
[ -z $CANDIDATE       ] && export CANDIDATE=$DATE
[ -z $MAJOR           ] && MAJOR=0
[ -z $MINOR           ] && MINOR=1
[ -z $BRANCH          ] && BRANCH=1
[ -z $TOOLCHAIN_PATH  ] && TOOLCHAIN_PATH=$SDK_DIR/test_root/c2/daily/bin
#[ -z $TOOLCHAIN_PATH  ] && TOOLCHAIN_PATH=`readlink -f /c2/local/c2/daily-jazz2l/bin`
# -z $QT_INSTALL_DIR  ] && QT_INSTALL_DIR=$SDK_DIR/test_root/QtopiaCore-4.6.1-generic
# -z $QT_INSTALL_DIR  ] && QT_INSTALL_DIR=/c2/local/QtopiaCore-4.6.1-generic
[ -z $INSTALL_DIR     ] && INSTALL_DIR=/local/$DATE
[ -z $PUBLISH_DIR     ] && PUBLISH_DIR=/local/$DATE


#CONFIG_BUILD_DRY=1
#CONFIG_BUILD_HELP=1
#CONFIG_BUILD_LOCAL=1
CONFIG_BUILD_CLEAN=1
CONFIG_BUILD_SDK=1
#CONFIG_BUILD_CHECKOUT=1
CONFIG_BUILD_PKGSRC=1
CONFIG_BUILD_DEVTOOLS=1
CONFIG_BUILD_SPI=1
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

if [ ! -f $SDK_DIR/Makefile ] && [ ! -f $SDK_DIR/vertical/Makefile.pvr ]; then
    CONFIG_BUILD_SDK=1
fi
if [ "$TOOLCHAIN_PATH" = "$SDK_DIR/test_root/c2/daily/bin" ] && [ ! -d $SDK_DIR/test_root/c2 ]; then
    CONFIG_BUILD_DEVTOOLS=1
fi

VERSION=${MAJOR}_${MINOR}
if [ $CONFIG_BUILD_CHECKOUT  ]; then
    MAKE_ENV="CANDIDATE=$CANDIDATE MAJOR=${MAJOR} MINOR=${MINOR} SDK_VERSION_ALL=${SDK_VERSION_ALL} \
	CVS_TAG=$CVS_TAG \
	TOOLCHAIN_PATH=$TOOLCHAIN_PATH"
else
    CHECKOUT=echo
    UPDATE=echo
    MAKE_ENV="CANDIDATE=$CANDIDATE MAJOR=${MAJOR} MINOR=${MINOR} SDK_VERSION_ALL=${SDK_VERSION_ALL} \
	CVS_TAG=$CVS_TAG CHECKOUT=$CHECKOUT UPDATE=$UPDATE \
	TOOLCHAIN_PATH=$TOOLCHAIN_PATH"
    #	QT_INSTALL_DIR=${QT_INSTALL_DIR} TOOLCHAIN_PATH=$TOOLCHAIN_PATH"
fi

if [ $CONFIG_BUILD_HELP       ]; then
    create_rebuild_envs
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
create_rebuild_envs
if [ $CONFIG_BUILD_DRY       ]; then
    exit 0
fi

mkdir -p $BUILD_DIR    $SDK_DIR
mkdir -p $INSTALL_DIR  $LOG_DIR
rm  $DIST_DIR/l $DIST_DIR/r $DIST_DIR/i >/dev/null
ln -s $DIST_DIR/$DATE      $DIST_DIR/i
ln -s $DIST_DIR/$DATE.log  $DIST_DIR/l
ln -s $DIST_DIR/$DATE.txt  $DIST_DIR/r

pushd $BUILD_DIR         
recho "Checkout projects/sw/sdk"

if [ $CONFIG_BUILD_SDK       ]; then
    CHECKOUT_OPTION=
    [ "$CVS_TAG" != "" ] && CHECKOUT_OPTION="-r $CVS_TAG"
    mkdir -p sdk/vertical 
    rm -rf sdk/Makefile sdk/vertical/Makefile.pvr
    cvs -q co -AP -d sdk $CHECKOUT_OPTION projects/sw/sdk/Makefile
    pushd sdk; cvs -q co -AP -d vertical $CHECKOUT_OPTION projects/sw/sdk/vertical/Makefile.pvr; popd
    #sed -i -e "s|^\(SOURCE_DIR.*\)=.*|\1= $SOURCE_DIR|g" sdk/Makefile 
    #sed -i -e "s|^\(SOURCE_DIR.*\)=.*|\1= $SOURCE_DIR|g" sdk/vertical/Makefile.pvr
fi

recho "Start new mission"
pushd $SDK_DIR
[ -d source ] || ln -s $SOURCE_DIR source

if [ $CONFIG_BUILD_CLEAN ]; then
    make $MAKE_ENV clean
    rm -rf $PKG_DIR temp test_root test
    rm -rf ${SDK_TARGET_ARCH}-sdk-*
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
    recho "SDK build $2 success"

    recho "SDK build $3" 
    if [ "$3" != "nop" ]; then
    make -f $1 $MAKE_ENV $3 >> $4 2>&1
    if [ $? -ne 0 ]; then
        recho "SDK build $3 fail at `date`"
        let "HAVE_ERROR++"
        return -1
    fi
    recho "SDK build $3 success"
    fi

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
        if [ $? -ne 0 ]; then
            update_indexlog "Devtools:1:$devtoolslog" $indexlog
            update_indexlog "Buildroot:1:$buildrootlog" $indexlog
        else
            update_indexlog "Devtools:0:$devtoolslog" $indexlog
            update_indexlog "Buildroot:0:$buildrootlog" $indexlog
        fi
fi
        
if [ $CONFIG_BUILD_SPI ]; then
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/jtag"  > $spilog
        $SSHCMD ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/prom" >> $spilog
        build_packages "Makefile" "diag-src" "diag-bin" "$spilog" 
        if [ $? -ne 0 ]; then
            update_indexlog "SPI:1:$spilog" $indexlog
        else
            update_indexlog "SPI:0:$spilog" $indexlog
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
	    HAVE_ERROR_SAVED=$HAVE_ERROR
            build_packages "vertical/Makefile.pvr" "nop" "kernel-bin" "$kernellog"
	    if [ $? -ne 0 ]; then
	        update_indexlog "Kernel:1:$kernellog" $indexlog
	    else
	        update_indexlog "Kernel:0:$kernellog" $indexlog
	    fi
	    HAVE_ERROR=$HAVE_ERROR_SAVED
	fi

        ##---------------------------------------------------------------------------------------
	if [ "$SDK_TARGET_ARCH" = "jazz2"  ]; then
            build_packages "vertical/makefile.pvr" "kernel-src" "kernel-bin" "$kernellog"
            if [ $? -ne 0 ]; then
                update_indexlog "kernel:1:$kernellog" $indexlog
            else
                update_indexlog "kernel:0:$kernellog" $indexlog
            fi
            build_packages "vertical/makefile.pvr" "nop" "kernel-nand-bin" "$kernelnandlog"
            if [ $? -ne 0 ]; then
                update_indexlog "kernelnand:1:$kernelnandlog" $indexlog
            else
                update_indexlog "kernelnand:0:$kernelnandlog" $indexlog
            fi
	    HAVE_ERROR_SAVED=$HAVE_ERROR
	    build_packages "vertical/Makefile.pvr" "kernel-src-2632" "kernel-bin-2632" "$kernel2632log"
	    if [ $? -ne 0 ]; then
	        update_indexlog "Kernel2632:1:$kernel2632log" $indexlog
	    else
	        update_indexlog "Kernel2632:0:$kernel2632log" $indexlog
	    fi
	    HAVE_ERROR=$HAVE_ERROR_SAVED
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
recho_time_consumed

if [ $CONFIG_BUILD_PUBLISH ]; then
    scp_upload_logs
    #copy build packages to server
    if [ $HAVE_ERROR -ne 0 ] ; then
        echo "build fail, see rlog*.txt for detail" >$PKG_DIR/BUILD_FAIL
        cp $indexlog $PKG_DIR/
        cp $rlog.log.txt $PKG_DIR/
        cp $rlog.env.txt $PKG_DIR/
        cp $SDK_DIR/test/logs.tar.gz $PKG_DIR/
    fi
    if [ $HAVE_ERROR -eq 0 ] ; then
        ssh ${SDK_CVS_USER}@10.16.13.200 "mkdir -p /sdk/$SDK_TARGET_ARCH/dev/weekly/$DATE"
        scp -r $PKG_DIR/* ${SDK_CVS_USER}@10.16.13.200:/sdk/$SDK_TARGET_ARCH/dev/weekly/$DATE/
    fi
fi
popd   #pushd $SDK_DIR
if [ $CONFIG_BUILD_PUBLISH ]; then
    ##  Report
    #----------------------------------------------------------------------
    #create and send report
    HTML_REPORT=${SDK_TARGET_ARCH}_${TREE_PREFIX}_sdk_daily.html
    #the cgi need 3 variable pre-defined. it need a tail '/' in SDK_RESULTS_DIR, otherwise, we need fix the dev_logs//100829.log
    #SDK_RESULTS_DIR=/build/$SDK_TARGET_ARCH/build_result/ SDK_CVS_USER=janetliu SDK_TARGET_ARCH=$SDK_TARGET_ARCH 
    ./html_generate.cgi  >$DIST_DIR/$HTML_REPORT
    #fix: // in url like:  href='https://access.c2micro.com/jazz2_msp_dev_logs//100829.log
    sed -i 's:_logs//1:_logs/1:g' $DIST_DIR/$HTML_REPORT
    scp $DIST_DIR/$HTML_REPORT  ${SDK_CVS_USER}@access.c2micro.com:/home/${SDK_CVS_USER}/public_html/

    addto_send mingliu@c2micro.com
    checkadd_fail_send_list
    addto_cc jsun@c2micro.com weli@c2micro.com mxia@c2micro.com
    addto_cc hguo@c2micro.com addto_cc janetliu@c2micro.com
    mail_title="$SDK_TARGET_ARCH daily build report: $HAVE_ERROR errors"
    (
        echo "Click link to watch status: "
        echo "https://access.c2micro.com/~${SDK_CVS_USER}/$HTML_REPORT" 
        #[ $HAVE_ERROR -eq 0 ] && 
        echo "a local build copied to: 10.16.13.200:/sdk/$SDK_TARGET_ARCH/dev/weekly/$DATE/"
        list_fail_url_tail
        tail -2 $rlog.log.txt 
    ) 2>&1 | mail -s"$mail_title" -c $CCTO $SENDTO
fi

