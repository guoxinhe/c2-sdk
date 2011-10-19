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
sleep 30
date >/qa.log
date >/qadaemon.log
sleep 120
date >>/qa.log

mkdir -p /nfshome
mount -t nfs -o nolock 10.16.6.204:/mean/c2 /nfshome
/nfshome/setdate.sh

CONFIG_MYIP=`/sbin/ifconfig eth0|sed -n 's/.*inet addr:\([^ ]*\).*/\1/p'`
CONFIG_BOARDLOG=/nfshome/boardlog/$(date +%y%m%d.%H%M)-$CONFIG_MYIP
mkdir -p  $CONFIG_BOARDLOG
df >>/qa.log
df >>$CONFIG_BOARDLOG/qa.log
sync

mkdir -p /mnt
rm    /mnt/yaffs
ln -s /data /mnt/yaffs

echo "$(date): Start test" >>/qa.log
echo "$(date): Start test" >>$CONFIG_BOARDLOG/qa.log
#upgrade itself for next usage
[ -f /qatestcfg.sh ] && . /qatestcfg.sh
cp /qaboardtest.sh        $CONFIG_BOARDLOG/
cp /qatestcfg.sh          $CONFIG_BOARDLOG/
sync
cp /nfshome/qaboardtest.sh /qaboardtest.sh
sync

morningreboot()
{
  #poll for a basic crontab task
  /nfshome/setdate.sh
  rebooth=07;
  rebootm=58;
  while true;do
    h=`date +%H`;
    m=`date +%M`;
    mkdir -p  $CONFIG_BOARDLOG
    echo "$(date): morning boot daemon footprint" >>/qadaemon.log
    echo "$(date): morning boot daemon footprint" >>$CONFIG_BOARDLOG/qadaemon.log
    sync;
    if test "$h" = "$rebooth"; then
    if test $m -ge $rebootm; then
        echo "$(date): Reboot" >>/qadaemon.log
        echo "$(date): Reboot" >>$CONFIG_BOARDLOG/qadaemon.log
        reboot -f;
    fi
    fi
    sleep 60;
  done
}

morningreboot &

#there maybe lots of test plans to execute, detect and run them.
test "$CONFIG_TEST_FS"  = "1" && /nfshome/fs-nandroid/fs_newtest.sh
sync
test "$CONFIG_TEST_LTP" = "1" && /nfshome/ltp-test/ltp_newtest.sh
sync


sleep 3600
/nfshome/setdate.sh
echo "$(date): Reboot" >>/qa.log
echo "$(date): Reboot" >>$CONFIG_BOARDLOG/qa.log
reboot -f

