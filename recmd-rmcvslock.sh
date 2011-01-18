#!/bin/bash

[ -z $1 ] && echo "arg 1 is cvs.log file name" && exit 1

nr_timeout=1800
monitor_log=$1
debugon=$2
debug(){
    [ $debugon ] && echo $@
    echo $@ >>rmcvslock.log
}
sleep 5
debug "pid=$$ `date` :Start monitor cvs log file $monitor_log"

while [ ! -f $monitor_log ] && [ $nr_timeout -gt 10 ] ; do
    debug "Waiting for $monitor timeout=$nr_timeout "
    nr_timeout=$(($nr_timeout-5))
    sleep 5
done
if [ ! -f $monitor_log ] && [ $nr_timeout -le 10 ] ; then
    debug "Waiting for $monitor timeout=$nr_timeout, exit "
    exit 1
fi

tail_age=0
tail_old="lnczylsqswkzshwxtnfyes"
while [ -f $monitor_log ]; do
    tail_line="`sed -n '$p' $monitor_log`"
    [ "$tail_line" == "done" ] && break
    if [ "$tail_old" != "$tail_line" ]; then
        tail_age=0
        tail_old="$tail_line"
    else
        tail_age=$(($tail_age+5))
    fi
    if [ $tail_age -gt 72000 ]; then  #old than 20 hours
        debug "There is a line old than 20 hours, exit: $tail_line "
        break
    fi
    if [ "$tail_line" == "" ]; then
        sleep 5 
        continue
    fi

    lock_line="`echo $tail_line | grep 'waiting for .* lock in '`"
    if [ "$lock_line" == "" ] ; then
        sleep 5
        continue
    #else 
        #debug "find lock line $lock_line"
    fi

    lock_path=`echo $tail_line | sed "s,.*waiting for .* lock in \(.*\),\1,g"`
    locked_files=`find $lock_path -name "#cvs.*" 2>/dev/null`

    if [ "$locked_files" == "" ]; then
        #debug "no lock files find in $lock_path"
        sleep 5
        continue
    fi

    seconds_now=`date +%s`

    for i in $locked_files ; do
        seconds_file=`date -r $i +%s 2>/dev/null`
        if [ "$seconds_file" == "" ]; then
            continue
        fi
        file_age=`expr $seconds_now - $seconds_file`
        if [ "$file_age" -ge "180" ]; then 
            debug "file $i, dirty age in seconds: $file_age, removed"
            rm -rf $i
        fi
    done
    sleep 5
done
