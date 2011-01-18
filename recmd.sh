#!/bin/bash

tm_a=`date +%s`
recho_time_consumed()
{
    tm_b=`date +%s`
    tm_c=$(($tm_b-$tm_a))
    tm_h=$(($tm_c/3600))
    tm_m=$(($tm_c/60))
    tm_m=$(($tm_m%60))
    tm_s=$(($tm_c%60))
    echo "$@" "$tm_c seconds / $tm_h:$tm_m:$tm_s consumed."
}
./recmd-rmcvslock.sh recmd.all.log &

>recmd.all.log
./recmd-update.sh                      >>recmd.all.log 2>&1
#./recmd-branch.sh                     >>recmd.all.log 2>&1
#./recmd-tag.sh sure $CVS_TAG          >>recmd.all.log 2>&1
recho_time_consumede             >>recmd.all.log
echo done                        >>recmd.all.log

