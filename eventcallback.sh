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
    mail_title="event callback scripts"
    (
        echo "$mail_title on `date`"
        echo THISCAL=$0
        echo THISPATH=`pwd`
        echo THISTID=`date +%Y%m%d%H%M%S`
        echo THISMAC=`/sbin/ifconfig eth0 | grep 'HWaddr' | sed 's/.*HWaddr \(.*\)/\1/'`
        echo THISIP=`/sbin/ifconfig eth0 | grep 'inet addr' | sed 's/.*addr:\(.*\)\(  Bcast.*\)/\1/'`
	uname -a

    ) 2>&1 | mail -s"$mail_title" -c $CCTO $SENDTO

