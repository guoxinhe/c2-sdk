#!/bin/sh
#repo forall -c "pwd; git log -n 1 --after='2011-06-14 9:00'"
#repo forall -c "git log -n 1 --after='2011-06-14 9:00' >/tmp/x; if [ \`stat -c %s /tmp/x\` -gt 0 ];then pwd;cat /tmp/x;echo;fi"
after="--after='1 day ago'"
before=
x=/tmp/x$$
p="--name-status"
while [ $# -gt 0 ] ; do
    case $1 in
    -p | p ) p="-p"; shift;;
    -h | --help) 
       echo "${0##*/} [ -p ] [ -ndays-ago ]";
       echo "    -p    display patch";
       echo "    -n    from n days ago";
       exit 0;
       shift;;
    *) break;
    esac
done
days=${1:-1}
to=${2:-0}

[ $days -gt 1 ] && after="--after='$days days ago'"
[ $to   -gt 0 ] && before="--before='$to days ago'"

#repo forall -c "git log -n 3 --after='$after' >$x; if [ \`stat -c %s $x\` -gt 0 ];then pwd;cat $x;echo;fi"
if [ -d .git ]; then
    git log "$before" "$after" $p -b -w ;
else
sep="--------------------------------------------------------------------------"
repo forall -c "git log $before $after >$x; 
if [ \`stat -c %s $x\` -gt 0 ];then 
    echo;
    pwd;
    echo $sep;
    export PAGER=
    git log $before $after $p -b -w ;
    echo;
fi" 
rm $x
fi


