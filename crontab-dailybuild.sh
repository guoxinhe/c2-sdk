#!/bin/sh


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

while [ $# -gt 0 ] ; do
    case $1 in
    --fix) CONFIG_FIX=y; shift;;
    *) break;
    esac
done


dstdir=${1-/local/hguo/android-c2-branch}
buildsh=${2-/local/hguo//make-nfs-droid-fs}

if [ ! -d $dstdir ] ; then
    [ ! -d $dstdir ] && recho "no dir $dstdir found, please manual create it"
    cat <<ENDREPO
    
    mkdir -p $dstdir
    pushd $dstdir
    repo init -u ssh://git.bj.c2micro.com/mentor-mirror/build/manifests.git -b devel 
    repo sync
    repo start --all devel
    popd
ENDREPO
    exit 0;
fi
[ ! -f $buildsh ] && (recho no build script found; exit 0);

if [ $CONFIG_FIX ] ; then
    echo Using fix mode...
fi
pushd $dstdir
tm_a=`date +%s`
if [ -z $CONFIG_FIX ] ; then
mkdir -p cronlog
repo sync 2>&1 >>cronlog/reposync.log 
fi
recho_time_consumed $tm_a "The repo sync "

nfsroot=nfs-droid-`date +%Y%m%d%H%M%S`
tm_a=`date +%s`
if [ -z $CONFIG_FIX ] ; then
$buildsh -m -f $nfsroot 2>&1 >>cronlog/repobuild.log
else
$buildsh  $nfsroot 2>&1 >>cronlog/repobuild.log
fi
recho_time_consumed $tm_a "The repo build "
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
addto_send hguo@c2micro.com
addto_cc   hguo@c2micro.com
    mail_title="Android auto daily build result"
    (
        echo "$mail_title"
        [ -f nfs-droid/run ] && echo run method:
        [ -f nfs-droid/run ] && cat nfs-droid/run
        [ -f nfs-droid/run ] || echo build fail

    ) 2>&1 | mail -s"$mail_title" -c $CCTO $SENDTO

