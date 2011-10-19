#!/bin/sh
CONFIG_SCRIPT=`readlink -f $0`
TOP=${CONFIG_SCRIPT%/*}
cd $TOP

CONFIG_MYIP=`/sbin/ifconfig eth0|sed -n 's/.*inet addr:\([^ ]*\).*/\1/p'`
export PATH="$PATH:./"

##############################################################################################
#testitems="fat32 ext2 ext3 ntfs"
testitems="yaffs"
report_dir=$TOP/test_report/$(date +%y%m%d.%H)


test ! -d $report_dir  && mkdir -p $report_dir
chmod 777 $report_dir
rm -rf    $report_dir/*
echo "$(date) pid=$$" >$report_dir/testing.lock
chmod 777              $report_dir/testing.lock
cat <<ENDOFME >$report_dir/testingenv.log
#!/bin/sh
# run on $(date) pid=$$
top=$top
uname="             $(uname -a)"
CONFIG_MYIP="       $CONFIG_MYIP"
ENDOFME
chmod 777      $report_dir/testingenv.log
echo "$(date) start testing: pid=$$" >>$report_dir/testing.log
chmod 777      $report_dir/testing.log
##############################################################################################

$TOP/runltplite.sh
$TOP/runltp 
$TOP/runalltests.sh



echo "$(date) testing all done:):):):):):):):):) " >>$report_dir/testing.log



echo "$(date) testing all done:):):):):):):):):) " >>$report_dir/testing.log
cp $report_dir/testing.lock $report_dir/testing.done
rm -rf $report_dir/testing.lock
