#!/bin/bash

. ~/.bash_profile

export SDK_TARGET_ARCH=jazz2
export SDK_TARGET_GCC_ARCH=TANGO
export SDK_KERNEL_VERSION=2.6.23

SDK_CVS_USER=`echo $CVSROOT | sed 's/:/ /g' | sed 's/\@/ /g' | awk '{print $2}'`
DATE=`date +%y%m%d`
cd /build/jazz2/rel

tm_a=`date +%s`
[ -z "$MISSION" ] && export MISSION=sdk_branch
[ -z "$rlog" ] && export rlog=$HOME/rlog/rlog.$MISSION
mkdir -p $HOME/rlog
touch $rlog.log.txt
recho()
{
    echo -en `date +"%Y-%m-%d %H:%M:%S"` " " >>$rlog.log.txt
    echo "$@" >>$rlog.log.txt
    echo "$@"
    scp  $rlog.log.txt ${SDK_CVS_USER}@access.c2micro.com:/home/${SDK_CVS_USER}/public_html/
}

report_time_consumed()
{
    tm_b=`date +%s`
    tm_c=$(($tm_b-$tm_a))
    tm_h=$(($tm_c/3600))
    tm_m=$(($tm_c/60))
    tm_m=$(($tm_m%60))
    tm_s=$(($tm_c%60))
    recho "$@" "$tm_c seconds / $tm_h:$tm_m:$tm_s consumed."
}

DO_TAG=Y
PRODUCT=$*
WORK_DIR=$PWD
cd $WORK_DIR
mkdir -p $WORK_DIR/build_result
>$WORK_DIR/build_result/progress.log
recho Start build script
if [ $# -lt "1" ]
then
    recho "brach_build.sh <product> <product> ..."
    recho "Supported product: pvr, nmp"
    report_time_consumed
    exit 1
fi

if [ ! -d sdk ]; then
    recho Start cvs checkout projects/sw/sdk
    cvs -q co -A -r $CVS_TAG -d sdk projects/sw/sdk
fi

# Set CVS tag and candidate for SDK makefile 
MAJOR=0
MINOR=10
BRANCH=3L

if [ ! -f $WORK_DIR/sdk/source/.tagversion ]; then
    mkdir -p $WORK_DIR/sdk/source
    echo 0 > $WORK_DIR/sdk/source/.tagversion
fi

TAGVER=`cat $WORK_DIR/sdk/source/.tagversion`
if [ "$DO_TAG" = "Y" ]; then
    let "TAGVER++"
    echo $TAGVER > $WORK_DIR/sdk/source/.tagversion
fi

# export environment variable for SDK Makefile
export CANDIDATE=${BRANCH}-${TAGVER}
export CVS_TAG=${SDK_TARGET_ARCH}-SDK-${MAJOR}_${MINOR}-${CANDIDATE}
export QT_INSTALL_DIR=$WORK_DIR/sdk/test_root/QtopiaCore-4.6.1-generic
export TOOLCHAIN_PATH=$WORK_DIR/sdk/test_root/c2/daily/bin
export SDK_VER=${MAJOR}.${MINOR}-${BRANCH}
export INSTALL_DIR=/build/sdk-install/c2-${SDK_TARGET_ARCH}-sdk-${SDK_VER}
ENV="CANDIDATE=${CANDIDATE} CVS_TAG=${CVS_TAG} QT_INSTALL_DIR=${QT_INSTALL_DIR} \
     TOOLCHAIN_PATH=${TOOLCHAIN_PATH} MAJOR=${MAJOR} MINOR=${MINOR}"


recho Start do tag
# do tag
if [ "$DO_TAG" = "Y" ]; then

    recho "CVS tag $TAGVER :  $CVS_TAG"
    if [ $TAGVER -eq 1 ]; then
        if [ -d $WORK_DIR/tag ]; then
            cd $WORK_DIR/tag
	    ./branch.sh.tmp
            ./tag.sh sure $CVS_TAG > $WORK_DIR/build_result/tag.log 2>&1
        fi
    else
        if [ -d $WORK_DIR/tag ]; then
            cd $WORK_DIR/tag
            ./tag.sh sure $CVS_TAG > $WORK_DIR/build_result/tag.log 2>&1
        fi
    fi
    recho "CVS tag done."

fi

# check-out sdk
cd $WORK_DIR/sdk
recho "Check out sdk work directory"
rm Makefile
recho cvs -q update -CAPd -r $CVS_TAG
cvs -q update -CAPd -r $CVS_TAG
recho "Check out sdk work directory : done"
recho TAGVER =$TAGVER

# build development tools when first compiled
if [ $TAGVER -eq 1 ]; then
    ERROR=0
    make clean
    #make $ENV > $WORK_DIR/build_result/devtools.log 2>&1
    recho "build devtools-src devtools-src-test devtools-bin"
    make $ENV devtools-src devtools-src-test devtools-bin >$WORK_DIR/build_result/devtools.log 2>&1
    if [ $? -ne 0 ]; then
        let "ERROR++"
	recho "    ==>build error"
    fi
    recho "build diag-src diag-bin"
    make $ENV diag-src diag-bin >$WORK_DIR/build_result/diag.log 2>&1
    if [ $? -ne 0 ]; then
        let "ERROR++"
	recho "    ==>build error"
    fi
    recho "build u-boot-src u-boot-bin"
    make $ENV u-boot-src u-boot-bin >$WORK_DIR/build_result/u-boot.log 2>&1
    if [ $? -ne 0 ]; then
        let "ERROR++"
	recho "    ==>build error"
    fi
    recho "build c2_goodies-src c2_goodies-bin"
    make $ENV c2_goodies-src c2_goodies-bin >$WORK_DIR/build_result/c2goodies.log 2>&1
    if [ $? -ne 0 ]; then
        let "ERROR++"
	recho "    ==>build error"
    fi
    recho "build qt-src qt-bin"
    make $ENV qt-src qt-bin >$WORK_DIR/build_result/qt.log 2>&1
    if [ $? -ne 0 ]; then
        let "ERROR++"
	recho "    ==>build error"
    fi

    if [ $ERROR -ne 0 ]; then
	report_time_consumed "build has error, send fail report and exit"
        echo "Failed!!!" | mail -s "devtools build failed on release branch" hguo@c2micro.com janetliu@c2micro.com
        exit 1
    fi
    recho "Install built toolchain to ${INSTALL_DIR}, server 200"
    make $ENV INSTALL_DIR=${INSTALL_DIR} install
    scp -r ${INSTALL_DIR}/c2-jazz2* ${SDK_CVS_USER}@10.16.13.200:/sdk/${SDK_TARGET_ARCH}/rel/candidate/
    if [ -d ${INSTALL_DIR}/${SDK_TARGET_ARCH}-sdk-${SDK_VER}-$TAGVER ]; then
        ssh ${SDK_CVS_USER}@10.16.13.200 "mkdir -p /sdk/${SDK_TARGET_ARCH}/rel/candidate/c2-${SDK_TARGET_ARCH}-sdk-${SDK_VER}/${SDK_VER}-$TAGVER"
        scp -r ${INSTALL_DIR}/${SDK_TARGET_ARCH}-sdk-${SDK_VER}-$TAGVER/* \
        ${SDK_CVS_USER}@10.16.13.200:/sdk/${SDK_TARGET_ARCH}/rel/candidate/c2-${SDK_TARGET_ARCH}-sdk-${SDK_VER}/${SDK_VER}-$TAGVER
    fi
fi

# compile SDK
recho "Start compiling SDK: $PRODUCT"

for i in $PRODUCT; do
    ERROR=0
    if [ ! vertical/Makefile.$i ]; then
        report_time_consumed "$i isn't supported"
        exit 1
    fi
    recho "build doc"
    #make $ENV -f vertical/Makefile.$i > $WORK_DIR/build_result/$i-$DATE.log 2>&1
    make $ENV PRODUCT=${SDK_TARGET_ARCH}-sdk -f vertical/Makefile.$i doc-jazz2
    recho "build kernel-src kernel-bin kernel-nand-bin"
    make $ENV PRODUCT=${SDK_TARGET_ARCH}-sdk -f vertical/Makefile.$i kernel-src kernel-bin kernel-nand-bin >$WORK_DIR/build_result/kernel-$DATE.log 2>&1
    if [ $? -ne 0 ]; then
        let "ERROR++"
	recho "    ==>build error"
    fi
    recho "build hdmi-jazz2-src hdmi-jazz2-bin"
    make $ENV PRODUCT=${SDK_TARGET_ARCH}-sdk -f vertical/Makefile.$i hdmi-jazz2-src hdmi-jazz2-bin >$WORK_DIR/build_result/hdmi-$DATE.log 2>&1
    if [ $? -ne 0 ]; then
        let "ERROR++"
	recho "    ==>build error"
    fi
    recho "build sw_media-src sw_media-bin sw_media_doc"
    make $ENV PRODUCT=${SDK_TARGET_ARCH}-sdk -f vertical/Makefile.$i sw_media-src sw_media-bin sw_media_doc >$WORK_DIR/build_result/swmedia-$DATE.log 2>&1
    if [ $? -ne 0 ]; then
        let "ERROR++"
	recho "    ==>build error"
    fi
    recho "build vivante-src vivante-bin"
    make $ENV PRODUCT=${SDK_TARGET_ARCH}-sdk -f vertical/Makefile.$i vivante-src vivante-bin >$WORK_DIR/build_result/vivante-$DATE.log 2>&1
    if [ $? -ne 0 ]; then
        let "ERROR++"
	recho "    ==>build error"
    fi
    recho "build sw_c2apps-src demo-bin"
    make $ENV PRODUCT=${SDK_TARGET_ARCH}-sdk -f vertical/Makefile.$i sw_c2apps-src demo-bin >$WORK_DIR/build_result/swc2app-$DATE.log 2>&1
    if [ $? -ne 0 ]; then
        let "ERROR++"
	recho "    ==>build error"
    fi
    recho "build u-boot-src u-boot-bin"
    #u-boot is used by factory-udisk user-udisk, rebuild in $(TAGVER) >1 for safely ref.(not need in maintree daily/weekly build)
    make $ENV u-boot-src u-boot-bin >$WORK_DIR/build_result/u-boot.log 2>&1
    if [ $? -ne 0 ]; then
        let "ERROR++"
	recho "    ==>build error"
    fi
    recho "build factory-udisk user-udisk"
    make $ENV PRODUCT=${SDK_TARGET_ARCH}-sdk -f Makefile factory-udisk user-udisk >$WORK_DIR/build_result/factory-user-$DATE.log 2>&1
    if [ $? -ne 0 ]; then
        let "ERROR++"
	recho "    ==>build error"
    fi
    if [ $ERROR -ne 0 ]; then
        report_time_consumed "build fail, send mail report this"
        echo "Failed!!!" | mail -s "SDK ${SDK_VER}-$TAGVER failed" hguo@c2micro.com janetliu@c2micro.com
        exit 1
    fi

    recho "Install built SDK to ${INSTALL_DIR}, server 200"
    make -f vertical/Makefile.$i $ENV INSTALL_DIR=${INSTALL_DIR} install

    INSTALL_LIST=`ls -t ${INSTALL_DIR}`
    PRODUCT_NAME=`echo ${INSTALL_LIST} |cut -f 1 -d ' '`
    ssh ${SDK_CVS_USER}@10.16.13.200 "mkdir -p /sdk/${SDK_TARGET_ARCH}/rel/candidate/c2-${SDK_TARGET_ARCH}-sdk-${SDK_VER}/${SDK_VER}-$TAGVER"
    scp -r ${INSTALL_DIR}/${PRODUCT_NAME}/* \
        ${SDK_CVS_USER}@10.16.13.200:/sdk/${SDK_TARGET_ARCH}/rel/candidate/c2-${SDK_TARGET_ARCH}-sdk-${SDK_VER}/${SDK_VER}-$TAGVER
    echo "Get them at 10.16.13.200:/sdk/jazz2/rel/candidate/c2-${SDK_TARGET_ARCH}-sdk-${SDK_VER}/${SDK_VER}-$TAGVER" | mail -s "SDK ${PRODUCT_NAME} is available" hguo@c2micro.com janetliu@c2micro.com  roger@c2micro.com mingliu@c2micro.com 

    recho "built SDK $i mission completely"
done

report_time_consumed "All tasks done: "
#install SDK packages
#scp -r ${WORK_DIR}/sdk/${PRODUCT_NAME} `whoami`@10.16.13.200:/sdk/msp_rel/candidate/${PRODUCT_NAME}-${CANDIDATE}
#echo "Get them at 10.16.13.200:/sdk/msp_rel/candidate/${PRODUCT_NAME}-${CANDIDATE}" | mail -s "SDK build sucessfully on release branch: ${PRODUCT_NAME}" roger@c2micro.com frliu@c2micro.com ayiwang@c2micro.com adaliu@c2micro.com ryang@c2micro.com mduan@c2micro.com

