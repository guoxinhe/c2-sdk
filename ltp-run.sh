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
    export PATH=$PATH:/local/c2
    [ -f /home/c2net ] || cp -f /local/c2/c2net /home; 
    [ -f /home/authorized_keys ] || cp -f /local/c2/authorized_keys /home; 
    [ -f /.ssh/authorized_keys ] || cp -f /local/c2/authorized_keys /.ssh;
    [ -f /local/hguo/nfsroot/autoltp/ltpstatus ] && . /local/hguo/nfsroot/autoltp/ltpstatus
    d=`diff /home/work/run.sh /local/c2/ltp-run.sh`
    [ "$d" != "" ] && (cp -f /local/c2/ltp-run.sh /home/work/run.sh;sync;echo "ltp-run.sh updated";)
    mkdir -p /local/hguo/nfsroot/ltpresult
    echo $THISIP >/local/hguo/nfsroot/ltpresult/clientip
    rm -f /local/hguo/nfsroot/ltpresult/done
    cd /local/hguo/nfsroot/ltprelease
    ./runltplite.sh -p -q  -l /local/hguo/nfsroot/ltpresult/resultlog.$ltp_kernelbuild -d /local/hguo/nfsroot/ltpresult
    echo "done" >/local/hguo/nfsroot/ltpresult/done
}

ltp_test
