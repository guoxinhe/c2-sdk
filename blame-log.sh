#!/bin/sh

log=${1:-t}
ts=tmp$$.sed
sed -n '/^[^:]*:[[:digit:]]*:\ error:\ / p' $log >$ts

    lines=`sed -n '$=' $ts`
    while [ "$lines"  != "" ]; do
       #sed -n '$p' $ts  >>rindex
       #sed -i '$d' $ts
       #echo reverse line $lines
       ln=`sed -n '1p' $ts`
       sed -i '1d' $ts
       lines=`sed -n '$=' $ts`

       echo Line : $ln
    done

rm $ts
