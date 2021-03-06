#!/bin/bash

##  cron debug message code, these setting does not pass to Makefile
#----------------------------------------------------------------------
#export MISSION=`echo $0 | sed 's:.*/\(.*\):\1:'`
export MISSION=${0##*/}
export rlog=$HOME/rlog/rlog.$MISSION
mkdir -p $HOME/rlog/
touch $rlog.log.txt
loglines=`sed -n '$=' $rlog.log.txt`
recho()
{
    #progress echo, for debug during run as the crontab task.
    if [ ! -z "$rlog" ] ; then
    echo `date +"%Y-%m-%d %H:%M:%S"` " $@" >>$rlog.log.txt
    fi
    if [ -t 1 -o -t 2 ];then
    echo `date +"%Y-%m-%d %H:%M:%S"` " $@"
    fi
}

tm_a=`date +%s`
recho_time_consumed()
{
    tm_b=`date +%s`
    tm_c=$((tm_b-$1))
    tm_h=$((tm_c/3600))
    tm_m=$((tm_c/60))
    tm_m=$((tm_m%60))
    tm_s=$((tm_c%60))
    shift
    recho "$@" "$tm_c seconds / $tm_h:$tm_m:$tm_s consumed."
}

addto_send()
{
    while [ $# -gt 0 ] ; do
        email=$1
        x=`echo $1 | grep "@"`
        if [ $? -ne 0 ]; then
            email=${email}@c2micro.com
        fi
        if [ "$SENDTO" = "" ]; then
            SENDTO=$email ;
        else
          r=`echo $SENDTO | grep $email`
          if [ "$r" = "" ]; then
            SENDTO=$SENDTO,$email ;
          fi
        fi
        shift
    done
    export SENDTO
}


## sync from San Jose to Beijing

#remote=blackhole
remote=saturn
dst=/c2/server/c2
src=/c2/local/c2

today=`ssh $remote date +%y%m%d`
yesterday=`ssh $remote date -d yesterday +%y%m%d`


sync_folder()
{
    recho rsync -avzHS --stats --delete --delete-after --bwlimit=256 $3 $4 $5 $6 $7 $8 $9  \
        $remote:$src/$1 $dst/$2
    rsync -avzHS --stats --delete --delete-after --bwlimit=256 $3 $4 $5 $6 $7 $8 $9  \
        $remote:$src/$1 $dst/$2
    ret=$?
    if [ $ret -eq 0 ]; then
        recho "    Operate success"
    else
        recho "    Operate fail, error code=$ret"
    fi
}
sync_c2localc2()
{
    recho rsync -avzHS --stats --delete --delete-after --bwlimit=256 --exclude=sw_media \
        blackhole:$src/ $dst/
    rsync -avzHS --stats --delete --delete-after --bwlimit=256 --exclude=sw_media \
        blackhole:$src/ $dst/
    ret=$?
    if [ $ret -eq 0 ]; then
        recho "    Operate success"
    else
        recho "    Operate fail, error code=$ret"
    fi
}
sync_link()
{
    link=`ssh $remote ls -l $src/$1`
    recho "Check link " $link
    lval=`echo "$link" | sed "s,.* -> \(.*\),\1,g"`
    recho "  Check local link $dst/$lval"
    if [ -x $dst/$lval/bin/c2-linux-uclibc-gcc ] ; then
        recho "    Ready for rsync"
    else
        recho "    Target does not exist yet"
        return 1
    fi

    recho "  "rsync -avzHS $remote:$src/$1 $dst/
    rsync -avzHS $remote:$src/$1 $dst/
    ret=$?
    if [ $ret -eq 0 ]; then
        recho "    Operate success"
    else
        recho "    Operate fail, error code=$ret"
    fi
}


sync_folder $today/ $today/  --copy-dest=$dst/$yesterday/ 

sync_link daily
sync_link daily-jazz1
sync_link daily-jazz2
sync_link daily-jazz2l
sync_link daily-jazz2t
sync_link daily-mips32

sync_folder kernel/ kernel/ 
sync_c2localc2()

recho_time_consumed $tm_a  "All done"
addto_send hguo 
loglastlines=`sed -n '$=' $rlog.log.txt`
lines=$((loglines-loglastlines))
title="on dante, sync dante:$dst/$today is done"
(
    echo "this is auto generated email form crontab script"
    echo "  "
    tail -n $lines $rlog.log.txt
    echo "  "
    echo "  "
    echo `whoami`@`hostname`:`readlink -f $0`
    echo "`date`"
    echo "  "
) | mail -s "$title" $SENDTO

