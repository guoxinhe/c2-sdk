#!/bin/bash

. ~/.bash_profile

export TREE_PREFIX=msp_dev
export SDK_TARGET_ARCH=jazz2
export SDK_TARGET_GCC_ARCH=TANGO
export SDK_KERNEL_VERSION=2.6.23
export SDK_CVS_USER=`echo $CVSROOT | sed 's/:/ /g' | sed 's/\@/ /g' | awk '{print $2}'`

## rlog(runtime log, useful for running as crontab item) code start
#---------------------------------------------------------------------
tm_a=`date +%s`
export MISSION=`echo $0 | sed 's:.*/\(.*\):\1:'`
export rlog=$HOME/rlog/rlog.$MISSION
mkdir -p $HOME/rlog
touch $rlog.log.txt
recho()
{
    echo -en `date +"%Y-%m-%d %H:%M:%S"` " " >>$rlog.log.txt
    echo "$@" >>$rlog.log.txt
    echo "$@"
    [ -w /home/hguo/rlog ] && cp -f $rlog* /home/hguo/rlog/
    #scp  $rlog.log.txt ${SDK_CVS_USER}@access.c2micro.com:/home/${SDK_CVS_USER}/public_html/
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
add_cc()
{
    if [ "$CCTO" = "" ]; then 
        export CCTO=$1 ; 
        echo add $1 to cc list
    else
      r=`echo $CCTO | grep $1`
      if [ "$r" = "" ]; then 
        export CCTO=$CCTO,$1 ; 
        echo add $1 to cc list
      fi
    fi
}
add_cc hguo@c2micro.com

if [ $TREE_PREFIX = "msp_rel" ]
then
    cd /build/$SDK_TARGET_ARCH/rel/daily
else
    cd /build/$SDK_TARGET_ARCH/dev/daily
fi

export DATE=`date +%y%m%d`
WORK_DIR=$PWD
SDK_DIR=$WORK_DIR/sdk
HAVE_ERROR=0

mkdir -p $WORK_DIR/../build_result
cd $WORK_DIR/../build_result
export SDK_RESULTS_DIR=$PWD
cd $WORK_DIR

# Set CVS tag and candidate for SDK makefile 
MAJOR=0
MINOR=8
BRANCH=1
#export VERSION=daily
VERSION=${MAJOR}_${MINOR}
export SDK_VERSION_ALL=${SDK_TARGET_ARCH}-sdk-$DATE

# export environment variable for SDK Makefile
export CANDIDATE=$DATE
export BUILDTIMES=1

if [ $TREE_PREFIX = "msp_rel" ]; then
    export CVS_TAG="SDK-${VERSION}-${BRANCH}_Branch"
    
    echo "Check out sdk work directory"
    cvs -q co -AP -d sdk -r $CVS_TAG projects/sw/sdk
else
    export CVS_TAG=""
    #do not depend 3rd toolchain. build and use it.
    #export TOOLCHAIN_PATH=`readlink -f /c2/local/c2/daily-${SDK_TARGET_ARCH}/bin`

    echo "Check out sdk work directory"
    cvs -q co -AP -d sdk projects/sw/sdk
fi

cd $SDK_DIR

# compile SDK use script
echo "Start compiling SDK"
cd $WORK_DIR
./compile_sdk.sh
errornum=$?

# Check build result
if [ $errornum -ne 0 ]; then
    echo "Have error in course of build"
    let "HAVE_ERROR++"
fi


#install SDK packages
mkdir -p $SDK_RESULTS_DIR/$DATE
mkdir -p $SDK_RESULTS_DIR/$DATE.log
#we set DATE here before 0:00, but buildroot reset it to tomorrow
cp -f $SDK_DIR/test/tools-build/buildroot/makelog.* $SDK_RESULTS_DIR/$DATE.log/
cp -arf $SDK_DIR/${SDK_VERSION_ALL}/* $SDK_RESULTS_DIR/$DATE

if [ $HAVE_ERROR -eq 0 ]; then
    #copy to server
    scp -r $SDK_RESULTS_DIR/$DATE ${SDK_CVS_USER}@10.16.13.200:/sdk/${SDK_TARGET_ARCH}/dev/weekly
fi

export_fail_cc_list()
{
    #pickup the fail log's tail to email for a quick preview
    loglist=`cat $SDK_RESULTS_DIR/$DATE.txt`
    for i in $loglist ; do
        m=`echo $i | sed 's,\([^:]*\).*,\1,'`
        x=`echo $i | sed 's,[^:]*:\([^:]*\).*,\1,'`
        f=`echo $i | sed 's,[^:]*:[^:]*:\([^:]*\).*,\1,'`
        l=`echo $f | sed 's:.*/\(.*\):\1:'`
        if [ $x -ne 0 ]; then
            case $m in
            Kernel*) add_cc swine@c2micro.com ;;
            *);;
            esac
        fi
    done
}

list_fail_url_tail()
{
    #pickup the fail log's tail to email for a quick preview
    loglist=`cat $SDK_RESULTS_DIR/$DATE.txt`
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
                echo "    " "https://access.c2micro.com/~${SDK_CVS_USER}/${SDK_TARGET_ARCH}_${TREE_PREFIX}_logs/$DATE.log/$l.txt"
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
SCP_TARGET=/home/${SDK_CVS_USER}/public_html/${SDK_TARGET_ARCH}_${TREE_PREFIX}_logs/$DATE.log
ssh  ${SDK_CVS_USER}@access.c2micro.com "mkdir -p $SCP_TARGET"
sed -i "s,makelog.*,makelog.log," $SDK_RESULTS_DIR/$DATE.txt
pushd .
mkdir -p $SDK_DIR/test
cd $SDK_RESULTS_DIR/$DATE.log/
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
tar czvf $SDK_DIR/test/logs.tar.gz  *.log *.txt makelog*
scp $SDK_DIR/test/logs.tar.gz  ${SDK_CVS_USER}@access.c2micro.com:$SCP_TARGET/
ssh  ${SDK_CVS_USER}@access.c2micro.com "cd $SCP_TARGET; tar xzf logs.tar.gz; unix2dos * ; rm logs.tar.gz"
rm $SDK_DIR/test/logs.tar.gz
popd

HTML_REPORT=$SDK_RESULTS_DIR/${SDK_TARGET_ARCH}_${TREE_PREFIX}_sdk_daily.html
./html_generate.cgi >$HTML_REPORT
#fix: // in url like:  href='https://access.c2micro.com/jazz2_msp_dev_logs//100829.log
sed -i 's:_logs//1:_logs/1:g' $HTML_REPORT
scp $HTML_REPORT ${SDK_CVS_USER}@access.c2micro.com:/home/${SDK_CVS_USER}/public_html/

export_fail_cc_list
if [ $HAVE_ERROR -ne 0 ]; then
    mail_title="${SDK_TARGET_ARCH} SDK daily build failed on tree: ${TREE_PREFIX}"
    (
    echo "Click link to watch status: "
    echo "https://access.c2micro.com/~${SDK_CVS_USER}/${SDK_TARGET_ARCH}_${TREE_PREFIX}_sdk_daily.html" 
    list_fail_url_tail
    ) 2>&1 | mail -s"$mail_title" -c $CCTO jsun@c2micro.com janetliu@c2micro.com weli@c2micro.com mxia@c2micro.com boliu@c2micro.com wdiao@c2micro.com sliu@c2micro.com mingliu@c2micro.com 
else
    mail_title="${SDK_TARGET_ARCH} SDK daily build successful on tree: ${TREE_PREFIX}"
    (
    echo "Click link to watch status: "
    echo "https://access.c2micro.com/~${SDK_CVS_USER}/${SDK_TARGET_ARCH}_${TREE_PREFIX}_sdk_daily.html"
    list_fail_url_tail
    ) 2>&1 | mail -s"$mail_title" -c $CCTO janetliu@c2micro.com mingliu@c2micro.com 
fi

#if [ $HAVE_ERROR -ne 0 ]; then
    #OK we have done everything. trigger another low priority task
    MISSION=
    rlog=
    /build/jazz2l/daily/jazz2l_daily.sh -clean  &
#fi
