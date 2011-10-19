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

period=300
op_size=64
op_count=16000
max_size=102400

test_mesure=1
test_maxium=1

step_band_width=1024
min_band_width=$step_band_width
max_band_width=20480
b_band_width=0
FSTEST=$TOP/fs_test
LOGTOOL=$TOP/fs_test_tool

##############################################################################################
while getopts :b:k:r:p:s:n:l:c:f:m:e:z: OPTION
do
  case $OPTION in
  b) b_band_width=$OPTARG     ;; #band width
  r) report_dir=$OPTARG       ;;
  p) period=$OPTARG           ;;
  s) op_size=$OPTARG          ;; #max size in one rw, in KB.
  n) op_count=$OPTARG         ;; #max loop rw number.
  l) max_size=$OPTARG         ;; #max file size for rw, in KB.
  f) testitems=$OPTARG        ;;
  m) test_mesure=$OPTARG      ;;
  e) test_maxium=$OPTARG      ;;
  k) step_band_width=$OPTARG  ;;
  z) max_band_width=$OPTARG   ;;
  esac
done

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
testitems="         $testitems"
report_dir="        $report_dir"
period="            $period"
op_size="           $op_size"
op_count="          $op_count"
max_size="          $max_size"
test_mesure="       $test_mesure"
test_maxium="       $test_maxium"
step_band_width="   $step_band_width"
min_band_width="    $min_band_width"
max_band_width="    $max_band_width"
b_band_width="      $b_band_width"
FSTEST="            $FSTEST"
LOGTOOL="           $LOGTOOL"
ENDOFME
chmod 777      $report_dir/testingenv.log
echo "$(date) start testing: pid=$$" >>$report_dir/testing.log
chmod 777      $report_dir/testing.log
##############################################################################################

for target in $testitems; do
        echo "$(date) testing ${target} bandwidth=$b_band_width " >>$report_dir/testing.log
        PARAM=" -y -l $max_size -s $op_size -t $period -n $op_count"
        WLOG=$report_dir/w_${target}_max.log
        RLOG=$report_dir/r_${target}_max.log
        WPRS=$report_dir/gen_w_${target}_max.log
        RPRS=$report_dir/gen_r_${target}_max.log
        $FSTEST  $PARAM -o $WLOG -i /mnt/${target}/tn.dat -b $b_band_width  -w
        $FSTEST  $PARAM -o $RLOG -i /mnt/${target}/tn.dat -b $b_band_width  -r
        $LOGTOOL        -s $WLOG -d $WPRS
        $LOGTOOL        -s $RLOG -d $RPRS
done
for target in $testitems; do
    bandwidth=$min_band_width
    while test "$bandwidth" -le $max_band_width;do
        echo "$(date) testing ${target} bandwidth=$bandwidth " >>$report_dir/testing.log
        PARAM=" -y -l $max_size -s $op_size -t $period -n $op_count"
        WLOG=$report_dir/w_${target}_$bandwidth.log
        RLOG=$report_dir/r_${target}_$bandwidth.log
        WPRS=$report_dir/gen_w_${target}_all.log
        RPRS=$report_dir/gen_r_${target}_all.log
        $FSTEST $PARAM -o $WLOG -i /mnt/${target}/tn.dat -b $bandwidth    -w
        $FSTEST $PARAM -o $RLOG -i /mnt/${target}/tn.dat -b $bandwidth    -r
        $LOGTOOL       -s $WLOG -d $WPRS
        $LOGTOOL       -s $RLOG -d $RPRS
        bandwidth=$(($bandwidth + $step_band_width))
    done
done
echo "$(date) testing all done:):):):):):):):):) " >>$report_dir/testing.log
cp $report_dir/testing.lock $report_dir/testing.done
rm -rf $report_dir/testing.lock
