#!/bin/sh

# uboot setting:
# Goal: let uboot auto download the daily build kernel and run it.
# set gatewayip 10.16.6.1
# set serverip  10.16.13.195
# set bootfile  /build2/android/jazz2t-c2sdk_android/p/nand-droid/zvmlinux.bin
# set set loadaddr 0xa0000000
# set bootargs 'nfs;go'

# Please copy this file to target board and let it auto run it after bootup.
# Makesure your server side is ready prepare these service listed in script.
#----------------------------------------------------------------------------

#sleep >120 seconds to wait system bring up
if test ! -x /nfshome/setdate.sh; then
    sleep 30
    date >/qa.log
    date >/qadaemon.log
    sleep 120
    date >>/qa.log
    mkdir -p /nfshome
    mount -t nfs -o nolock 10.16.6.204:/mean/c2 /nfshome
fi

/nfshome/setdate.sh

CONFIG_MYIP=`/sbin/ifconfig eth0|sed -n 's/.*inet addr:\([^ ]*\).*/\1/p'`
CONFIG_BOARDLOG=/nfshome/boardlog/$(date +%y%m%d.%H%M)-$CONFIG_MYIP
mkdir -p  $CONFIG_BOARDLOG
df >>/qa.log
df >>$CONFIG_BOARDLOG/qa.log
sync

echo "$(date): Start test" >>/qa.log
echo "$(date): Start test" >>$CONFIG_BOARDLOG/qa.log
#upgrade itself for next usage
[ -f /qatestcfg.sh ] && . /qatestcfg.sh
cp /qaboardtest.sh        $CONFIG_BOARDLOG/
cp /qatestcfg.sh          $CONFIG_BOARDLOG/
sync
cp /nfshome/qaboardtest.sh /qaboardtest.sh
sync
dinnertime="02 06 11 17";
morningreboot()
{
  #poll for a basic crontab task
  /nfshome/setdate.sh
  rebooth=02;
  rebootm=58;
  while true;do
    h=`date +%H`;
    m=`date +%M`;
    if test $m -eq 10; then
        /nfshome/setdate.sh
    fi
    mkdir -p  $CONFIG_BOARDLOG
    echo "$(date): morning boot daemon footprint" >>/qadaemon.log
    echo "$(date): morning boot daemon footprint" >>$CONFIG_BOARDLOG/qadaemon.log
    sync;

    for rebooth in $dinnertime; do
    if test "$h" = "$rebooth"; then
    if test $m -ge $rebootm; then
        echo "$(date): Reboot" >>/qadaemon.log
        echo "$(date): Reboot" >>$CONFIG_BOARDLOG/qadaemon.log
        reboot -f;
    fi
    fi
    done
    sleep 60;
  done
}

morningreboot &

#there maybe lots of test plans to execute, detect and run them.
if test "$CONFIG_TEST_FS"  = "1" ; then
    /nfshome/fs-nandroid/fs_newtest.sh
    /nfshome/nfsroot/jazz2-rootfs/ltp/ltp-full-20090228/ltp_newtest.sh
    sync
fi
if test "$CONFIG_TEST_LTP" = "1" ; then
    /ltp/ltp-full-20090228/ltp_newtest.sh
    sync
fi


sleep 28800; #3600 * 8 = 28800
/nfshome/setdate.sh
echo "$(date): Reboot" >>/qa.log
echo "$(date): Reboot" >>$CONFIG_BOARDLOG/qa.log
reboot -f

