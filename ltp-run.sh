#!/bin/sh
THISIP=`/sbin/ifconfig eth0 | grep 'inet addr' | sed 's/.*addr:\(.*\)\(  Bcast.*\)/\1/'`

mkdir -p /local /home/work /.ssh
mount -o nolock -t nfs 10.16.8.4:/local /local
[ -f /.ssh/authorized_keys ] || cp -f /local/c2/authorized_keys /.ssh;
[ -f /local/hguo/nfsroot/autoltp/ltpstatus ] && . /local/hguo/nfsroot/autoltp/ltpstatus
d=`diff /home/work/run.sh $ltp_runsh`
[ "$d" != "" ] && (cp -f $ltp_runsh /home/work/run.sh;sync;)

mkdir -p $ltp_result
echo $THISIP >$ltp_clientip
rm -f $ltp_doneflag
cd $ltp_release
./$ltp_testcmd -p -q  -l $ltp_resultlog -d $ltp_result
echo "done" > $ltp_doneflag
