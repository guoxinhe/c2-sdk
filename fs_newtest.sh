#!/bin/sh
CONFIG_SCRIPT=`readlink -f $0`
TOP=${CONFIG_SCRIPT%/*}
cd $TOP

export PATH="$PATH:./"

##############################################################################################
testitems="fat32 ext2 ext3 ntfs"
report_dir=$TOP/test_report

period=300
period=30
op_size=64
op_count=16000
max_size=1024000

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
  b) b_band_width=$OPTARG     ;;
  r) report_dir=$OPTARG       ;;
  p) period=$OPTARG           ;;
  s) op_size=$OPTARG          ;;
  n) op_count=$OPTARG         ;;
  l) max_size=$OPTARG         ;;
  f) testitems=$OPTARG        ;;
  m) test_mesure=$OPTARG      ;;
  e) test_maxium=$OPTARG      ;;
  k) step_band_width=$OPTARG  ;;
  z) max_band_width=$OPTARG   ;;
  esac
done

test ! -d $report_dir  && mkdir -p $report_dir
##############################################################################################

for target in $testitems; do
    df | grep "/mnt/${target}" || continue;
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
    df | grep "/mnt/${target}" || continue;
    bandwidth=$min_band_width                                                
    while test "$bandwidth" -le $max_band_width;do                           
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
