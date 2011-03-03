#!/bin/sh

THISTID=`date +%Y%m%d%H%M%S`
THISMAC=`/sbin/ifconfig eth0 | grep 'HWaddr' | sed 's/.*HWaddr \(.*\)/\1/'`
THISIP=`/sbin/ifconfig eth0 | grep 'inet addr' | sed 's/.*addr:\(.*\)\(  Bcast.*\)/\1/'`
THISUSR=`whoami`
THISHOST=`uname -n`
THISKV=`uname -v`
THISARGC=$#
THISARGV=$@

func_nfs(){
    mdone=`cat /etc/mtab |  grep "$1 "`
    if [ "$mdone" != "" ]; then
        echo Already mounted $1 #: $mdone
        return 0
    fi

    host=${1%%:*}
    hostdir=${1##*:}
    #do not mount itself, loop mount, dangerous
    [ "$host" == "$(hostname)" ] && return 0 
    [ "$host" == "$THISIP" ] && return 0

    mkdir -p $2
    mount -o nolock -t nfs $1 $2
    echo mount nfs $1 --\> $2
}
ltp_test()
{
    mkdir -p /local /home/work /.ssh
    func_nfs 10.16.8.4:/local                 /local
    [ -f /.ssh/authorized_keys ] || cp -f /local/c2/authorized_keys /.ssh;
    [ -f /local/hguo/nfsroot/autoltp/ltpstatus ] && . /local/hguo/nfsroot/autoltp/ltpstatus
    d=`diff /home/work/run.sh $ltp_runsh`
    [ "$d" != "" ] && (cp -f $ltp_runsh /home/work/run.sh;sync;echo "$ltp_runsh updated";)
    mkdir -p $ltp_result
    echo $THISIP >$ltp_clientip
    rm -f $ltp_doneflag
    cd $ltp_release
    ./$ltp_testcmd -p -q  -l $ltp_result/resultlog.$ltp_kernelbuild -d $ltp_result
    echo "done" > $ltp_doneflag
}

ltp_test
