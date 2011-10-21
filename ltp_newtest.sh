#!/bin/sh
CONFIG_SCRIPT=`readlink -f $0`
TOP=${CONFIG_SCRIPT%/*}
cd $TOP

CONFIG_MYIP=`/sbin/ifconfig eth0|sed -n 's/.*inet addr:\([^ ]*\).*/\1/p'`
export PATH="$PATH:./"

##############################################################################################
#testitems="fat32 ext2 ext3 ntfs"
testitems="yaffs"
h=`date +%H`;
if test $h -ge 11; then
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
chmod 777      $report_dir/testingenv.log
echo "$(date) start testing: pid=$$" >>$report_dir/testing.log
chmod 777      $report_dir/testing.log
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
$TOP/runltp -c 2 -i 2 -m 2,4,10240,1 -D 2,10,10240,1 -p -q \
	-l $LOGFILE -o $OUTPUTFILE -C $FAILCMDFILE -d $TMPDIR

echo "$(date) testing all done:):):):):):):):):) " >>$report_dir/testing.log
cp $report_dir/testing.lock $report_dir/testing.done
rm -rf $report_dir/testing.lock
