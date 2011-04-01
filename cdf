#!/bin/sh

[ $# -ne 1 ] && exit 0

src=`readlink -f $1`
if [ -f $src ];then
    cd ${src%/*}
else
    cd $src
fi
