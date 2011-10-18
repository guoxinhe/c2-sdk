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
sleep 120                                                                    
date >>/qa.log                             
                                  
mkdir -p /nfshome                                                            
mount -t nfs -o nolock 10.16.6.204:/mean/c2 /nfshome                         
/nfshome/setdate.sh                                                          
df >>/qa.log                                        
sync                                                

mkdir -p /mnt                                       
rm    /mnt/yaffs                                       
ln -s /data /mnt/yaffs                              
date >>/qa.log                                      
echo "Start test" >>/qa.log              
#upgrade itself
cp /nfshome/qaboardtest.sh /qaboardtest.sh
sync

#there maybe lots of test plans to execute, detect and run them.
test -x /nfshome/testplan.sh               && /nfshome/testplan.sh
test -x /nfshome/fs-nandroid/fs_newtest.sh && /nfshome/fs-nandroid/fs_newtest.sh
sync                                                

sleep 3600
/nfshome/setdate.sh                                                          
h=`date +%k`;
if test $h -ge 8 -a $h -lt 20 ; then
reboot -f
fi

#poll for a basic crontab task
rebooth=07;
rebootm=58;
while true;do
    h=`date +%H`;
    m=`date +%M`;
    if test "$h" = "$rebooth"; then
    if test $m -ge $rebootm; then
        reboot -f;
    fi
    fi
    sleep 60;
done
