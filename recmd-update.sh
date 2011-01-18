#!/bin/sh

# update all SDK codes

CONTENT=`cat sdk_content`
rlog=${0##*/}

recho()
{
    #progress echo, for debug during run as the crontab task.
    echo -en `date +"%Y-%m-%d %H:%M:%S"` " " >>$rlog.history.txt
    echo "$@" >>$rlog.history.txt
    echo "$@"
}
recho_time_used()
{
    tm_start=$1
    tm_stop=$2
    shift 2
    tm_c=$(($tm_stop-$tm_start))
    tm_h=$(($tm_c/3600))
    tm_m=$(($tm_c/60))
    tm_m=$(($tm_m%60))
    tm_s=$(($tm_c%60))
    recho "$@" "$tm_c seconds / $tm_h:$tm_m:$tm_s consumed."
}
for i in $CONTENT; do
    recho "updating $i"
    tm_a=`date +%s`
    tm_action="update"
    if [ -e $i ]; then
        tm_action="update"
        cvs -q update -CPd $i
    else
        tm_action="checkout"
        cvs -q co $i
    fi
    tm_b=`date +%s`
    recho_time_used $tm_a $tm_b "$tm_action"
done
echo "update done"

