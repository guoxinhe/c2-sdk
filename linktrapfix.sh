#!/bin/sh
###################################################
#  /c2/local/c2/daily* is rsynced from SJ blackhole
#  the network speed is slow and the link may point to
#  a 'future' folser, causes engineer can not use it.
#  check and move it to an older available version.

alllinks="
daily       
daily-jazz1 
daily-jazz2 
daily-jazz2l
daily-jazz2t
daily-mips32
"

today=
yesday=
alldates=`ls -d [[:digit:]]*`

for d in $alldates; do
    yesday=$today
    today=$d
done

if [ -t 1 -o -t 2 ];then
echo today=$today
echo yesterday=$yesday
fi

for i in $alllinks; do
    [ -d $i ] && continue;
    link=`readlink -f $i`
    yesd=$yesday/${link##*/}
    if [ -d $yesd ]; then
        rm $i
        ln -s $yesd $i
        echo "relink $i -> $yesd"
    fi
done
