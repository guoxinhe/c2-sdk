#!/bin/sh
CONFIG_SCRIPT=`readlink -f $0`
TOP=${CONFIG_SCRIPT%/*}
cd $TOP

CONFIG_MYIP=`/sbin/ifconfig eth0|sed -n 's/.*inet addr:\([^ ]*\).*/\1/p'`
export PATH="$PATH:./"

##############################################################################################
#testitems="fat32 ext2 ext3 ntfs"
testitems="yaffs"
cat /proc/cpuinfo | grep processor.*:.*[1234567]
ret=$?
if test $ret -eq 0; then
    report_dir=$TOP/test_reportsmp/$(date +%y%m%d.%H)
else
    report_dir=$TOP/test_report/$(date +%y%m%d.%H)
fi

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
cat /proc/cpuinfo | grep processor.*:.*[01234567] >>$report_dir/testingenv.log

chmod 777      $report_dir/testingenv.log
echo "$(date) start testing: pid=$$" >>$report_dir/testing.log
chmod 777      $report_dir/testing.log
cp $CONFIG_SCRIPT $report_dir/
##############################################################################################

#$TOP/runltplite.sh
#$TOP/runalltests.sh

# -l LOGFILE      Log results of test in a logfile.
# -o OUTPUTFILE   Redirect test output to a file.
# -C FAILCMDFILE  Command file with all failed test cases.
# -d TMPDIR       Directory where temporary files will be created.
LOGFILE=$report_dir/result-log
OUTPUTFILE=$report_dir/result-output
FAILCMDFILE=$report_dir/result-failed
TMPDIR=$report_dir/result-temp

#TOP/runltp -c 2 -i 2 -m 2,4,10240,1 -D 2,10,10240,1 -p -q \
$TOP/runltp                                          -p -q \
	-l $LOGFILE -o $OUTPUTFILE -d $TMPDIR -C $FAILCMDFILE \
	>$report_dir/runltplite.log 2>&1

#TOP/runltplite.sh -i 1024 -m 128 -p -q \
$TOP/runltplite.sh                -p -q \
	-l $LOGFILE-lite -o $OUTPUTFILE-lite -d $TMPDIR-lite \
	>$report_dir/runltplite.log 2>&1

echo "$(date) testing all done:):):):):):):):):) " >>$report_dir/testing.log
cp $report_dir/testing.lock $report_dir/testing.done
rm -rf $report_dir/testing.lock
