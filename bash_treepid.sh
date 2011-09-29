#!/bin/sh

CONFIG_SHOW_CMD=0
CONFIG_KILL_CMD=0

# This script will kill all the child process id for a  given pid
#Store the current Process ID, we don't want to kill the current executing process id
CURPID=$$

# This is process id, parameter passed by user
ppid=$1

if [ -z $ppid ] ; then
   echo No PID given.
   exit;
else
   shift
fi

while [ $# -gt 0 ] ; do
    case $1 in
    --help    | -h)      CONFIG_BUILD_HELP=1 ; shift;;
    --verbose | -v)      CONFIG_SHOW_CMD=1   ; shift;;
    --kill    | -k)      CONFIG_KILL_CMD=1   ; shift;;
    *) 	echo "not support option: $1"; CONFIG_BUILD_HELP=1;  shift  ;;
    esac
done

sub0=$ppid
level=0
echo_head()
{(
    local r=0
    while [ $r -lt $level ];do
        r=$((r+1))
        echo -en "|   "
    done   
    echo -en "|-- "

)}

MYKILL()
{(
    cmd=
    if test $CONFIG_SHOW_CMD -eq 1 ; then
        #cmd=`ps $1 | grep $1 | sed 's/.* \(.*\)/\1/g'`
        cmd=`ps $1 | grep $1 | awk '{print $5 }'`
    fi
    echo $1 $cmd
    #kill -9 $1 >/dev/null 2>&1
)}
MYKILL $sub0
for sub1 in `ps -ef| awk '$3 == '$sub0' { print $2 }'` ; do level=0;echo_head;MYKILL $sub1;
for sub2 in `ps -ef| awk '$3 == '$sub1' { print $2 }'` ; do level=1;echo_head;MYKILL $sub2;
for sub3 in `ps -ef| awk '$3 == '$sub2' { print $2 }'` ; do level=2;echo_head;MYKILL $sub3;
for sub4 in `ps -ef| awk '$3 == '$sub3' { print $2 }'` ; do level=3;echo_head;MYKILL $sub4;
for sub5 in `ps -ef| awk '$3 == '$sub4' { print $2 }'` ; do level=4;echo_head;MYKILL $sub5;
for sub6 in `ps -ef| awk '$3 == '$sub5' { print $2 }'` ; do level=5;echo_head;MYKILL $sub6;
for sub7 in `ps -ef| awk '$3 == '$sub6' { print $2 }'` ; do level=6;echo_head;MYKILL $sub7;
for sub8 in `ps -ef| awk '$3 == '$sub7' { print $2 }'` ; do level=7;echo_head;MYKILL $sub8;
for sub9 in `ps -ef| awk '$3 == '$sub8' { print $2 }'` ; do level=8;echo_head;MYKILL $sub9;
done;done;done;done;done;done;done;done;done;

exit 0

#exit 0;
#
#arraycounter=1
#while true
#do
#        FORLOOP=FALSE
#        # Get all the child process id
#        for i in `ps -ef| awk '$3 == '$ppid' { print $2 }'`
#        do
#                if [ $i -ne $CURPID ] ; then
#                        procid[$arraycounter]=$i
#                        arraycounter=`expr $arraycounter + 1`
#                        ppid=$i
#                        FORLOOP=TRUE
#                fi
#        done
#        if [ "$FORLOOP" = "FALSE" ] ; then
#           arraycounter=`expr $arraycounter - 1`
#           ## We want to kill child process id first and then parent id's
#           while [ $arraycounter -ne 0 ]
#           do
#             echo "Killing procid[$arraycounter]=${procid[$arraycounter]}"
#             kill -9 "${procid[$arraycounter]}" >/dev/null
#             arraycounter=`expr $arraycounter - 1`
#           done
#         exit
#        fi
#done
#
