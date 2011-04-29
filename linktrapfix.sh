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

cd /c2/local/c2/

alldates=`ls -rd [[:digit:]]*`
if [ -t 1 -o -t 2 ];then 
    echo $alldates
fi

for i in $alllinks; do
    [ -t 1 -o -t 2 ] && echo Checking $i
    [ -d $i -a -x $i/bin/c2-linux-uclibc-gcc ] && continue;

    link=`ls -l $i | sed 's,.* -> [[:digit:]]*/\(.*\),\1,g'`
    ldir=`ls -l $i | sed 's,.* -> \([[:digit:]]*\)/.*,\1,g'`
    echo "Found bad link $i -> $ldir/$link"
    for yesday in $alldates; do
      yesd=$yesday/${link}
      if [ -d $yesd -a -x $yesd/bin/c2-linux-uclibc-gcc  ]; then
        rm $i
        ln -s $yesd $i
        echo "relink $i -> $yesd"
        break;
      fi
    done
done
