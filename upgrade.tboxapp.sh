#!/bin/sh
#-- for this script only.
packageName="upgrade.sh"
packageMD5="1234567890ABCDEF1234567890ABCDEF"
versionName="1.0.2"
versionNumber=102
releaseTime=2017/12/29:14:22
releaseDescription="Make support command and args"
releaseBy="Xinhe.Guo"
installDir=/usr/local/bin
installTo=$installDir/$(basename $0)

#-- for ota
EMMC=/dev/mmcblk0
EMMCP=/dev/mmcblk0p1
DLD=/media/sdcard/download
test -e $EMMC || DLD=~/download

URL=http://sirunv2.oss-cn-hangzhou.aliyuncs.com/fota/100926
URLVER=100
URLLIST=urllist
INITDISK=1
DOINSUPG=1
DOWNLIST=0
DOWNLOAD=0
MD5CHECK=0
NEWCHECK=0
UPGRADES=0
MAKEBALL=0
DEBUGSCR=0

md5str()
{
    md5sum $1 | sed -e 's/ .*//g' -e 's/\n//g' -e 's/\r//g'| tr a-z A-Z
}
upgrade_myself()
{
    test -e /usr/local || ln -s /usrdata/local /usr/local
    test -e /usrdata/local/bin || mkdir -p /usrdata/local/bin
    test -e /usr/local/bin || mkdir -p /usr/local/bin

    oldv=0
    appname=app_tbox_opencpu
    appdst=/usr/local/bin

    #check files and version number
    test -e $appname || (echo "No target software found, install nothing")
    test -e $appname || return
    test -x $appdst/$appname && oldv=$($appdst/$appname --versionnumber)
    test $oldv -gt $versionNumber && (echo "installed version is newer, no need upgrade")
    test $oldv -eq $versionNumber && (echo "installed version is up to date, no need upgrade")
    test $oldv -ge $versionNumber && return # no need upgrade.

    #update script
    test -e $installDir || mkdir -p $installDir
    test -e $installTo || (cp -rf $0 $installTo;chmod 755 $installTo; echo "copied $0 to $installTo")
    diff -q $installTo $0 >/dev/null 2>&1 || (cp -rf $0 $installTo;chmod 755 $installTo; echo "copied $0 to $installTo")

    #compatiable with old code.
    test -e ~/bin || mkdir -p ~/bin
    cp -f $0 ~/bin/; chmod 755 ~/bin/$(basename $0)

    MD5=$(md5str $appname)
    if test "$MD5" = "$packageMD5" ; then
        echo package md5 verified
        cp -f $appname $appdst/ ;
	chmod 755 $appdst/$appname
        echo $packageName upgraded to $appdst/$appname, version $versionName
    else
        echo package md5 $MD5 not equal $packageMD5. refuse upgrade.
    fi
}
check_emmc()
{
    test -e $EMMC || return   #return if no device
    test -e $EMMCP && return  #return if device created
    fdiskcmd=_tmpfdisk
    echo "n     "  >$fdiskcmd # new a partition
    echo "p     " >>$fdiskcmd # p   primary partition (1-4)
    echo "1     " >>$fdiskcmd # Partition number (1-4): 1
    echo "      " >>$fdiskcmd # First cylinder: Using default value 
    echo "      " >>$fdiskcmd # Last cylinder : Using default value 
    echo "w     " >>$fdiskcmd # Write and exit.
    echo "      " >>$fdiskcmd # Out   
    dd if=/dev/zero of=$EMMC bs=512 count=1
    cat $fdiskcmd | fdisk $EMMC
    sleep 1
    mkfs.vfat  "$EMMC"p1
    rm -f $fdiskcmd
    mkdir -p /media/sdcard
    mount -t vfat $EMMCP  /media/sdcard
    echo "Created device $EMMCP"
}

this_version()
{
    cat <<-EOF >&2
Tbox OTA upgrade utility $versionName ($versionNumber)
Copyright (C) 2018 Sirun Technology, Inc.
This is internal software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

	EOF
}
this_help()
{
    cat <<-EOF >&2

    OTA upgrade utility
    usage: ./${0##*/} <command> [ optional ]*
    command:
        downlist  download the ota's urllist
        download  download files in the urllist
        md5check  check the downloaded file's md5
        newcheck  check if file need upgrade.
        upgrades  try upgrade it.
        makeball  make upgrade tarball of this script.
    optional:
    --debug    show script debug info
    --url      set url of ota urllist
    --urlver   set url version of ota urllist
    --urllist  sepcify urllist file pathname
    --download sepcify download folder pathname
    --help     show this help
    --version  show this script version info.
    --versionname  show this script version name.
    --versionnumber  show this script version number.
	EOF
}
md5_check()
{
    nrErr=0
    f=0
    df=
    echo "Start md5 check on $(date)"
    echo
    for i in `cat $DLD/$URLLIST`; do
        f=$((1-f))
        if test $f -eq 1; then
            df=$i
            continue;
        fi
        df=$(echo $df | sed -e 's/.*\///g' -e 's/\n//g' -e 's/\r//g')
        MD52=$(echo $i | sed -e 's/\n//g' -e 's/\r//g' | tr a-z A-Z)
        echo checking file md5 $df
	if test -e $DLD/$df; then
            MD5=$(md5str "$DLD/$df")
            test "$MD5" = "$MD52" && echo good download
            test "$MD5" = "$MD52" || echo bad download
            test "$MD5" = "$MD52" || nrErr=$((nrErr+1))
	fi
        echo
    done
    test $nrErr -eq 0 && echo "Download: everything downloaded.       [   OK   ]"
    test $nrErr -ne 0 && echo "Download: something downloaded fail.   [  FAIL  ]"
    echo "Check md5 Time=$(date)"
}
md5_check_download()
{
    #instead of wget --no-check-certificate -P $DLD -i $DLD/$URLLIST
    nrErr=0
    f=0
    df=
    echo "Start download on $(date)"
    echo
    for i in `cat $DLD/$URLLIST`; do
        f=$((1-f))
        if test $f -eq 1; then
            df=$i
            continue;
        fi
	wgeturl=$(echo $df | sed -e 's/\n//g' -e 's/\r//g')
        case $wgeturl in
        http:*|https:*|ftp:*)
            ;;
        *) continue ;;#something invalid.
        esac
        df=$(echo $df | sed -e 's/.*\///g' -e 's/\n//g' -e 's/\r//g')
        MD52=$(echo $i | sed -e 's/\n//g' -e 's/\r//g' | tr a-z A-Z)
        echo checking before download $wgeturl to $DLD/$df
	if test -e $DLD/$df; then
            MD5=$(md5str "$DLD/$df")
            test "$MD5" = "$MD52" && echo "\talready downloaded. skip"
            test "$MD5" = "$MD52" && continue; #found alread downloaded.
            echo remove exist bad download file "$DLD/$df"
            rm -f "$DLD/$df"
	fi
        echo "\tstart download..."
        wget --no-check-certificate -O $DLD/$df $wgeturl
        echo "checking download file md5..."
        MD5=$(md5str "$DLD/$df")
        test "$MD5" = "$MD52" && echo good download md5: $MD5
        test "$MD5" = "$MD52" || echo bad download md5: $MD5 vs $MD52
        test "$MD5" = "$MD52" || nrErr=$((nrErr+1))
        echo
    done
    test $nrErr -eq 0 && echo "Download: everything downloaded.       [   OK   ]"
    test $nrErr -ne 0 && echo "Download: something downloaded fail.   [  FAIL  ]"
    echo "Finish download on $(date)"
}
do_upgrades()
{
    nrErr=0
    f=0
    df=
    echo "$(date) start upgrades in $DLD" >$DLD/upgrade.log
    for i in `cat $DLD/urllist`; do
        f=$((1-f))
        if test $f -eq 1; then
            df=$i
            continue;
        fi
        df=$(echo $df | sed -e 's/\n//g' -e 's/\r//g')
        MD52=$(echo $i | sed -e 's/\n//g' -e 's/\r//g' | tr a-z A-Z)
        echo url file is: $df >>$DLD/upgrade.log
        echo md5=$MD52 >>$DLD/upgrade.log
        df=$(echo $df | sed -e 's/.*\///g' -e 's/\n//g' -e 's/\r//g')
        rm -rf $DLD/tmp
        mkdir $DLD/tmp
        case $df in
        *.tar.gz|*.tgz) tar xzf $DLD/$df -C $DLD/tmp;;
        *.tar.bz2|*.bz2)  tar xjf $DLD/$df -C $DLD/tmp;;
        *) 	echo "not support format: $df";;
        esac
	test -x $DLD/tmp/upgrade.sh && (cd $DLD/tmp;echo "$(date) upgrade $df"; ./upgrade.sh;)>>$DLD/upgrade.log && continue
	test -x $DLD/tmp/install.sh && (cd $DLD/tmp;echo "$(date) install $df"; ./install.sh;)>>$DLD/install.log && continue
	test -x $DLD/tmp/upgrade.sh -o -x $DLD/tmp/install.sh || (cd $DLD/tmp;
		echo "$(date) no install/upgrade script found for $df"; ls -l;) >>$DLD/upgrade.log
        echo
    done
}

while [ $# -gt 0 ] ; do
    case $1 in
    downlist) DOWNLIST=1; shift;;
    download) DOWNLOAD=1; shift;;
    md5check) MD5CHECK=1; shift;;
    newcheck) NEWCHECK=1; shift;;
    upgrades) UPGRADES=1; shift;;
    makeball) MAKEBALL=1; shift;;
    debug | --debug) DEBUGSCR=1; shift;;
    --url) URL=$2; shift 2;;
    --urlver) URLVER=$2; shift 2;;
    --urllist) URLLIST=$2; shift 2;;
    --download) DLD=$2; shift 2;;
    --help) this_help; exit 0;;
    --version) this_version; exit 0;;
    --versionname) echo $versionName; exit 0;;
    --versionnumber) echo $versionNumber; exit 0;;
    *) 	echo "not support option: $1. use --help for help"; shift  ;;
    esac
done
if test $DEBUGSCR -eq 1; then
	echo "DLD      = " $DLD
	echo "URL      = " $URL
	echo "URLVER   = " $URLVER
	echo "URLLIST  = " $URLLIST
	echo "DOWNLIST = " $DOWNLIST
	echo "DOWNLOAD = " $DOWNLOAD
	echo "MD5CHECK = " $MD5CHECK
	echo "NEWCHECK = " $NEWCHECK
	echo "UPGRADES = " $UPGRADES
	echo "MAKEBALL = " $MAKEBALL
	echo "DEBUGSCR = " $DEBUGSCR
fi

if test $INITDISK -eq 1; then #always
    test -e $EMMCP || check_emmc
fi

if test $DOINSUPG -eq 1; then #always
    upgrade_myself
fi

test -e $DLD ||mkdir -p $DLD
if test $DOWNLIST -eq 1; then
    echo "versionNumber=$URLVER" >$DLD/versioninfo.txt
    echo "downloadUrl=$URL" >>$DLD/versioninfo.txt
    case $URL in
    http:*|https:*|ftp:*)
    diff -q $DLD/versioninfo.txt $DLD/versioninfo.old.txt || (
	rm -f $DLD/$URLLIST
        echo "download Urllist $(date)" >>$DLD/download.log
        wget --no-check-certificate -O $DLD/$URLLIST $URL
        cp $DLD/versioninfo.txt $DLD/versioninfo.old.txt)
	;;
    *) 	echo "not support url: $URL" ;;
    esac
fi

if test $DOWNLOAD -eq 1; then
    diff -q $DLD/$URLLIST $DLD/${URLLIST}.old || (
	md5_check_download >> $DLD/download.log
        cp $DLD/$URLLIST $DLD/${URLLIST}.old)
fi

if test $MD5CHECK -eq 1; then
    md5_check | tee $DLD/md5check.log
fi
if test $NEWCHECK -eq 1; then 
    test -e $installTo || echo script $installTo not installed yet.
    diff $installTo $0 || echo script $installTo is old than $0
fi
if test $UPGRADES -eq 1; then
    do_upgrades
fi
if test $MAKEBALL -eq 1; then
    rm -rf $DLD/tbox-ota-upgrade-${versionName}.tar.gz
    tar czvf $DLD/tbox-ota-upgrade-${versionName}.tar.gz $0   
fi

