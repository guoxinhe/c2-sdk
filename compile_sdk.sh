#!/bin/sh

if [ -z $DATE ]; then
    export DATE=`date +%y%m%d`
fi

# If tag ans candidate aren't defined, set them as daily build
if [ -z $CVS_TAG ]; then
    export CVS_TAG=""
fi
if [ -z $CANDIDATE ]; then
    export CANDIDATE=$DATE
fi

if [ -z $MAJOR ]; then
    MAJOR=0
    MINOR=8
    BRANCH=1
#    VERSION=weekly
fi

# set make environment
MAKE_ENV="CANDIDATE=$CANDIDATE CVS_TAG=$CVS_TAG MAJOR=${MAJOR} MINOR=${MINOR} SDK_VERSION_ALL=${SDK_VERSION_ALL}"
if [ ! -z $TOOLCHAIN_PATH ]; then
    MAKE_ENV="TOOLCHAIN_PATH=$TOOLCHAIN_PATH $MAKE_ENV"
fi

BUILD_DIR=$PWD
SDK_DIR=$BUILD_DIR/sdk
HAVE_ERROR=0
RETRY=10

cd $BUILD_DIR/../build_result
DIST_DIR=$PWD
cd $BUILD_DIR

# Define location of build result
INSTALL_DIR=$DIST_DIR/$DATE
indexlog=$DIST_DIR/$DATE.txt
LOG_DIR=$DIST_DIR/$DATE.log
devtoolslog=$LOG_DIR/devtools.log
buildrootlog=$LOG_DIR/makelog.$DATE
kernellog=$LOG_DIR/kernle.log
hdmilog=$LOG_DIR/hdmi.log
spilog=$LOG_DIR/spi.log
swmedialog=$LOG_DIR/swmedia.log
qtlog=$LOG_DIR/qt.log
swc2appslog=$LOG_DIR/swc2apps.log
c2goodieslog=$LOG_DIR/c2goodies.log
pvrtestdemolog=$LOG_DIR/pvrtestdemo.log
vivantelog=$LOG_DIR/vivante.log
timestampslog=$LOG_DIR/timestamps.log

mkdir -p $INSTALL_DIR
mkdir -p $LOG_DIR

if [ -d $SDK_DIR ]; then
    echo "SDK directory is $SDK_DIR"
else
    echo "SDK build directory inexistence"
    exit -1
fi

build_packages() {
    if [ $# -lt 4 ]; then 
        echo "usage : build_packages [Makefile] [source] [binary] [log file]"
        return -1
    fi

    CO_ERR=0
    echo "CVS checkout $2 start at `date`" >> $timestampslog
    echo "Use c2 tools: $TOOLCHAIN_PATH" >> $4
    while [ $CO_ERR -lt $RETRY ]
    do
        make -f $1 $MAKE_ENV $2 >> $4 2>&1
        if [ $? -eq 0 ]; then
            break;
        fi
        let "CO_ERR++"
        echo "Error : cvs checkout failed, retry = $CO_ERR" >> $4
    done
    echo "CVS checkout $2 end at `date`" >> $timestampslog
    if [ $CO_ERR -eq $RETRY ]; then
        return -1
    fi

    echo "SDK build $3 start at `date`" >> $timestampslog
    make -f $1 $MAKE_ENV $3 >> $4 2>&1
    if [ $? -ne 0 ]; then
        echo "SDK build $3 fail at `date`" >> $timestampslog
        let "HAVE_ERROR++"
         return -1
    fi
    echo "SDK build $3 end at `date`" >> $timestampslog

    return 0
}


# make clean
cd $SDK_DIR
make $MAKE_ENV clean
rm -rf ${SDK_TARGET_ARCH}-sdk-*
rm -f $indexlog


# the actual devtools log is buildroot log
ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/devtools" > $devtoolslog
ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/sdk" >> $devtoolslog
ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/strace" >> $devtoolslog
ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/oprofile" >> $devtoolslog
ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/directfb" >> $devtoolslog
ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/cmd" >> $devtoolslog
build_packages "Makefile" "devtools-src" "devtools-src-test devtools-bin" "$devtoolslog"
if [ $? -ne 0 ]; then
    echo "Devtools:1:$buildrootlog">>$indexlog
else
    echo "Devtools:0:$buildrootlog">>$indexlog
fi


ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/prom" > $spilog
ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/jtag" >> $spilog
build_packages "Makefile" "diag-src u-boot-src" "diag-bin u-boot-bin" "$spilog" 
if [ $? -ne 0 ]; then
    echo "SPI:1:$spilog">>$indexlog
else
    echo "SPI:0:$spilog">>$indexlog
fi 


build_packages "Makefile" "c2_goodies-src" "c2_goodies-bin" "$c2goodieslog"
if [ $? -ne 0 ]; then
    echo "C2_goodies:1:$c2goodieslog">>$indexlog
else
    echo "C2_goodies:0:$c2goodieslog">>$indexlog
fi


ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/Qt/qt-everywhere-opensource-src-4.6.1" >> $qtlog
build_packages "Makefile" "qt-src" "qt-bin" "$qtlog"
if [ $? -ne 0 ]; then
    echo "Qt:1:$qtlog">>$indexlog
else
    echo "Qt:0:$qtlog">>$indexlog
fi


make -f vertical/Makefile.pvr $MAKE_ENV doc


ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/kernel" > $kernellog
ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/bsp/hdmi" >> $kernellog
build_packages "vertical/Makefile.pvr" "kernel-src hdmi-jazz2-src" "kernel-bin kernel-nand-bin hdmi-jazz2-bin" "$kernellog"
if [ $? -ne 0 ]; then
    echo "Kernel:1:$kernellog">>$indexlog
else
    echo "Kernel:0:$kernellog">>$indexlog
fi


# if sw_media compile failed, exit
ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/media" > $swmedialog
ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/mx" >> $swmedialog
ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/build" >> $swmedialog
ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/csim" >> $swmedialog
ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/application" >> $swmedialog
ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/intrinsics" >> $swmedialog
ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/media" >> $swmedialog
build_packages "vertical/Makefile.pvr" "sw_media-src" "sw_media-bin" "$swmedialog"
if [ $? -ne 0 ]; then
    echo "Sw_media:1:$swmedialog">>$indexlog
    exit -1
else
    echo "Sw_media:0:$swmedialog">>$indexlog
fi

if [ `which dot 2>/dev/null` ]; then
    make $MAKE_ENV sw_media_doc
fi


ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/bsp" > $vivantelog
build_packages "vertical/Makefile.pvr" "vivante-src" "vivante-bin" "$vivantelog"
if [ $? -ne 0 ]; then
    echo "vivante:1:$vivantelog">>$indexlog
else
    echo "vivante:0:$vivantelog">>$indexlog
fi


ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/c2apps" > $swc2appslog

ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/c2apps" > $swc2appslog
ssh ${SDK_CVS_USER}@access.c2micro.com "./rmdeadlock.sh projects/sw/cmd/lirc" >> $swc2appslog
build_packages "vertical/Makefile.pvr" "sw_c2apps-src" "demo-bin" "$swc2appslog"
if [ $? -ne 0 ]; then
    echo "Sw_c2apps:1:$swc2appslog">>$indexlog
else
    echo "Sw_c2apps:0:$swc2appslog">>$indexlog
fi

factoryudisklog=$LOG_DIR/factoryudisk.log
make -f Makefile $MAKE_ENV  factory-udisk >> $factoryudisklog 2>&1
if [ $? -ne 0 ]; then
    echo "factory_udisk:1:$factoryudisklog">>$indexlog
else
    echo "factory_udisk:0:$factoryudisklog">>$indexlog
fi

userudisklog=$LOG_DIR/userudisk.log
make -f Makefile $MAKE_ENV  user-udisk >> $userudisklog 2>&1
if [ $? -ne 0 ]; then
    echo "user_udisk:1:$userudisklog">>$indexlog
else
    echo "user_udisk:0:$userudisklog">>$indexlog
fi


if [ $HAVE_ERROR -ne 0 ]; then
   exit -1
fi
