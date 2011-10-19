#!/bin/sh
#generate a line with format for client side run.
#    date -s "2011-10-14 11:48:00"

CONFIG_SCRIPT=`readlink -f $0`
TOP=${CONFIG_SCRIPT%/*}
cd $TOP

if [ -t 1 -o -t 2 ]; then
CONFIG_TTY=y
    echo "This is a crontab called script, will create a setdate.sh in its folder";
    echo "for hardware target test board's system sync its date/time"
fi
f=$TOP/setdate.sh
echo "#!/bin/sh"  >$f
echo "date -s \"$(date +%Y-%m-%d\ %H:%M:%S)\"" >>$f
chmod 755 $f



#other help jobs
mkdir -p boardlog
chmod 777 boardlog
