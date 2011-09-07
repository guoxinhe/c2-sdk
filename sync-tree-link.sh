#!/bin/sh
#set -ex
#basic settings auto detect, all name with prefix CONFIG_ is reported to web
#---------------------------------------------------------------
CONFIG_SCRIPT=`readlink -f $0`
TOP=${CONFIG_SCRIPT%/*}
cd $TOP
if [ -t 1 -o -t 2 ]; then
CONFIG_TTY=y
fi

CONFIG_MIRROR_SITE=/c2-mirror

#command line parse
while [ $# -gt 0 ] ; do
    case $1 in
    --help | -h)      CONFIG_BUILD_HELP=y ; shift;;
    *)  echo "not support option: $1"; CONFIG_BUILD_HELP=y;  shift  ;;
    esac
done
[ "$CONFIG_BUILD_HELP" != "" ] && exit 0
list_mirror_gits()
{
    find $CONFIG_MIRROR_SITE -path \*.git -type d
}
list_mirror_gits >$TOP/tmp$$.gl

sed /.*.repo/d <$TOP/tmp$$.gl >$TOP/tmp$$-b.gl

list=`cat $TOP/tmp$$-b.gl`;

for i in $list; do
   p=${i%/*}
   g=${i##*/}
   m=${p#$CONFIG_MIRROR_SITE/}

   if [ ! -h $m/$g ]; then
       [ "$CONFIG_TTY" == "y" ] && echo find new module $m/$g
       mkdir -p $m
       ln -s $i $m/$g
   fi
done 

rm *.gl
