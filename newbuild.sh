#!/bin/sh
#set -ex
#basic settings auto detect, all name with prefix CONFIG_ is reported to web
#---------------------------------------------------------------
CONFIG_DATE=`date +%y%m%d`
CONFIG_DATEH=`date +%y%m%d.%H`
CONFIG_MYIP=`/sbin/ifconfig eth0|sed -n 's/.*inet addr:\([^ ]*\).*/\1/p'`
CONFIG_SCRIPT=`readlink -f $0`
CONFIG_STARTTIME=`date`
CONFIG_STARTTID=`date +%s`
TOP=${CONFIG_SCRIPT%/*}
if [ -t 1 -o -t 2 ]; then
CONFIG_TTY=y
[ "${0:0:2}" = "./" ] && TOP=`pwd`
fi
cd $TOP

#---------------------------------------------------------------
CONFIG_BUILDTOP=$TOP
CONFIG_MAKEFILE=Makefile
CONFIG_GENHTML=`pwd`/scm/html_generate.cgi
CONFIG_ARCH=`make -f $CONFIG_MAKEFILE SDK_TARGET_ARCH`  #jazz2 jzz2t jazz2l
CONFIG_PKGDIR=`make -f $CONFIG_MAKEFILE PKG_DIR`
CONFIG_TREEPREFIX=sdkdev               #sdkdev sdkrel anddev andrel, etc, easy to understand
CONFIG_C2GCC_PATH=`readlink -f c2/daily/bin`
CONFIG_C2GCC_VERSION=`$CONFIG_C2GCC_PATH/c2-linux-gcc --version`
CONFIG_KERNEL=`make -f $CONFIG_MAKEFILE SDK_KERNEL_VERSION`
CONFIG_LIBC=uClibc-0.9.27
CONFIG_BRANCH_C2SDK=master  #one of: master, devel, etc.
CONFIG_BRANCH_ANDROID=devel  #one of: master, devel, etc.
CONFIG_CHECKOUT_C2SDK=checkout-c2sdk-tags.sh
CONFIG_CHECKOUT_ANDROID=checkout-android-tags.sh
CONFIG_PROJECT=SDK    #one of: SDK, android
CONFIG_WEBFILE="${CONFIG_ARCH}_${CONFIG_TREEPREFIX}_${HOSTNAME}-sdk_daily.html"
CONFIG_WEBTITLE="${CONFIG_ARCH}_${CONFIG_TREEPREFIX}_${HOSTNAME}-sdk_daily build"
CONFIG_WEBSERVERS="build@10.16.13.195:/var/www/html/build/$CONFIG_WEBFILE
                #build@10.0.5.193:/home/build/public_html/$CONFIG_WEBFILE
                     #hguo@10.16.5.166:/var/www/html/hguo/$CONFIG_WEBFILE
"
CONFIG_LOGSERVERS="build@10.16.13.195:/var/www/html/build/${CONFIG_ARCH}_${CONFIG_TREEPREFIX}_${HOSTNAME}_logs/$CONFIG_DATE.log
                #build@10.0.5.193:/home/build/public_html/${CONFIG_ARCH}_${CONFIG_TREEPREFIX}_${HOSTNAME}_logs/$CONFIG_DATE.log
                     #hguo@10.16.5.166:/var/www/html/hguo/${CONFIG_ARCH}_${CONFIG_TREEPREFIX}_${HOSTNAME}_logs/$CONFIG_DATE.log
"
CONFIG_PKGSERVERS="            build@10.16.13.195:/sdk-b2/${CONFIG_ARCH}/android-daily/android-${CONFIG_ARCH}-$CONFIG_DATE
                              #build@10.16.13.195:/sdk-b1/${CONFIG_ARCH}/android-daily/android-${CONFIG_ARCH}-$CONFIG_DATE
"
CONFIG_C2LOCALSERVERS="        build@10.16.13.200:/c2/local/c2/sw_media/$CONFIG_DATE-android
"
CONFIG_LOGSERVER=`echo $CONFIG_LOGSERVERS |awk '{print $1}'`
CONFIG_MAILLIST=hguo@c2micro.com
CONFIG_RESULT=$TOP/build_result/$CONFIG_DATE
CONFIG_LOGDIR=$CONFIG_RESULT.log
CONFIG_INDEXLOG=$CONFIG_RESULT.txt
CONFIG_HTMLFILE=$CONFIG_LOGDIR/web.html
CONFIG_EMAILFILE=$CONFIG_LOGDIR/email.txt
CONFIG_EMAILTITLE="$CONFIG_ARCH $CONFIG_TREEPREFIX daily build pass"
CONFIG_PATH=$CONFIG_C2GCC_PATH:$PATH
CONFIG_DEBUG=
CONFIG_BUILD_DRY=
CONFIG_BUILD_HELP=
CONFIG_BUILD_LOCAL=
CONFIG_BUILD_DOTAG=
CONFIG_BUILD_CLEAN=1
CONFIG_BUILD_SDK=
CONFIG_BUILD_CHECKOUT=1
CONFIG_BUILD_PKGSRC=1
CONFIG_BUILD_PKGBIN=1
CONFIG_BUILD_DEVTOOLS=
CONFIG_BUILD_SPI=
CONFIG_BUILD_DIAG=
CONFIG_BUILD_JTAG=
CONFIG_BUILD_UBOOT=
CONFIG_BUILD_C2GOODIES=
CONFIG_BUILD_QT=
CONFIG_BUILD_DOC=
CONFIG_BUILD_KERNEL=
CONFIG_BUILD_HDMI=
CONFIG_BUILD_SWMEDIA=1
CONFIG_BUILD_VIVANTE=
CONFIG_BUILD_C2APPS=
CONFIG_BUILD_FACUDISK=
CONFIG_BUILD_USRUDISK=
CONFIG_BUILD_ANDROIDNAND=1
CONFIG_BUILD_ANDROIDNFS=1
CONFIG_BUILD_XXX=
CONFIG_BUILD_PUBLISH=1
CONFIG_BUILD_PUBLISHLOG=1
CONFIG_BUILD_PUBLISHHTML=1
CONFIG_BUILD_PUBLISHEMAIL=1
CONFIG_BUILD_PUBLISHC2LOCAL=1

#command line parse
while [ $# -gt 0 ] ; do
    case $1 in
    --noco)      CONFIG_BUILD_CHECKOUT= ; shift;;
    --help | -h)      CONFIG_BUILD_HELP=y ; shift;;
    --set)
        set | grep CONFIG_ | sed -e 's/'\''//g' -e 's/'\"'//g' -e 's/ \+/ /g';
        exit 0; shift;;
    *) 	echo "not support option: $1"; CONFIG_BUILD_HELP=1;  shift  ;;
    esac
done

#step operations
if test $CONFIG_BUILD_HELP; then
    set | grep CONFIG_ | sed -e 's/'\''//g' -e 's/'\"'//g' -e 's/ \+/ /g';

cat <<EOFHELP

Please support these in Makefile
    make SDK_TARGET_ARCH      : return arch name
    make SDK_KERNEL_VERSION   : return kernel version name
    make PKG_DIR              : return package folder name
    make SOURCE_DIR           : return source folder name
    make sdk_folders          : create build used folders
    make lsvar                : list Makefile's important config variables

module build ops used in Makefile, example module name is:xxx
    make src_get_xxx src_package_xxx src_install_xxx src_config_xxx src_build_xxx bin_package_xxx bin_install_xxx
    make test_xxx clean_xxx help_xxx
EOFHELP
    exit 0;
fi


#---------------------------------------------------------------
jobtimeout=6000
lock=`pwd`/${0##*/}.lock
unlock_job()
{
  #rm -rf $lock.log #if exist, left for check, will be removed next lock
  rm -rf $lock
}
lock_job()
{
  if [ -f $lock ]; then
    burn=`stat -c%Z $lock`
    now=`date +%s`
    age=$((now-burn))
    #24 hour = 86400 seconds = 24 * 60 * 60 seconds.
    if [ $age -gt $jobtimeout ]; then
        rm -rf $lock
    else
        echo "an active task is running for $age seconds: `cat $lock`"
	echo "close it before restart: $lock"
	echo "`date` $(whoami)@$(hostname) `readlink -f $0` tid:$$, lock age: $age, life: $jobtimeout" >>$lock.log
        exit 1
    fi
  fi
  rm -rf $lock.log
  echo "`date` $(whoami)@$(hostname) `readlink -f $0` tid:$$ " >$lock
}
softlink()
{
    [ -h $2 ] && rm $2
    #[ -d ${2%/*} ] || mkdir -p ${2%/*}
    ln -s $1 $2
}
addto_send()
{
    while [ $# -gt 0 ] ; do
        email=$1
        x=`echo $1 | grep "@"`
        if [ $? -ne 0 ]; then
            email=${email}@c2micro.com
        fi
        if [ "$CONFIG_MAILLIST" = "" ]; then
            CONFIG_MAILLIST=$email ;
        else
          r=`echo $CONFIG_MAILLIST | grep $email`
          if [ "$r" = "" ]; then
            CONFIG_MAILLIST=$CONFIG_MAILLIST,$email ;
          fi
        fi
        shift
    done
    export CONFIG_MAILLIST
}
update_indexlog()
{
    #handle echo "Hdmi:1:$hdmilog">>$CONFIG_INDEXLOG
    #to : update_indexlog "Devtools:1:$devtoolslog" $CONFIG_INDEXLOG
    m=`echo $1 | sed 's,\([^:]*\).*,\1,'`
    x=`echo $1 | sed 's,[^:]*:\([^:]*\).*,\1,'`
    f=`echo $1 | sed 's,[^:]*:[^:]*:\([^:]*\).*,\1,'`
    l=`echo $f | sed 's:.*/\(.*\):\1:'`

    has=
    [ -f $2 ] && has=`grep ^$m: $2`
    if [ $has ];then
        sed -i "s,$m:.*,$1,g" $2
        echo "debug: $2 find $m and replaced $m:$x "
    else
        echo "$1" >>$2
        echo "debug: $2 not find $m, appended: $1"
    fi

    #create broken log system
    if [ "$x" != "0" ]; then
        mkdir -p ${CONFIG_RESULT}/blog
        BLOG=${CONFIG_RESULT}/blog/$CONFIG_DATE-${CONFIG_ARCH}-${CONFIG_TREEPREFIX}-$m.log
        [ -f $BLOG ] || ln -s $f  $BLOG;
    fi
}
recho_time_consumed()
{
    tm_b=`date +%s`
    tm_c=$((tm_b-$1))
    tm_h=$((tm_c/3600))
    tm_m=$((tm_c/60))
    tm_m=$((tm_m%60))
    tm_s=$((tm_c%60))
    shift
    echo "$@" "$tm_c seconds / $tm_h:$tm_m:$tm_s consumed."
}
addto_buildfail()
{
    while [ $# -gt 0 ] ; do
        if [ "$FAILLIST_BUILD" = "" ]; then
            FAILLIST_BUILD=$1 ;
        else
          r=`echo $FAILLIST_BUILD | grep $1`
          if [ "$r" = "" ]; then
            FAILLIST_BUILD=$FAILLIST_BUILD,$1 ;
          fi
        fi
        shift
    done
    export FAILLIST_BUILD
}
addto_resultfail()
{
    while [ $# -gt 0 ] ; do
        if [ "$FAILLIST_RESULT" = "" ]; then
            FAILLIST_RESULT=$1 ;
        else
          r=`echo $FAILLIST_RESULT | grep $1`
          if [ "$r" = "" ]; then
            FAILLIST_RESULT=$FAILLIST_RESULT,$1 ;
          fi
        fi
        shift
    done
    export FAILLIST_RESULT
}
checkout_from_repositories()
{
    if [ $CONFIG_BUILD_CHECKOUT ];then
        pushd `readlink -f source`
        BR=$CONFIG_BRANCH_C2SDK
        echo "ereport: `date` repo start --all $BR"
        repo start $BR --all
        echo "ereport: `date` Start repo sync"
        repo sync
        echo "ereport: `date` repo start --all $BR"
        repo start $BR --all
        echo "ereport: `date` repo forall -c 'git branch'"
        repo forall -c "git branch"
        popd

        pushd `readlink -f android`
        BR=$CONFIG_BRANCH_ANDROID
        echo "ereport: `date` repo start --all $BR"
        repo start $BR --all
        echo "ereport: `date` Start repo sync"
        repo sync
        echo "ereport: `date` repo start --all $BR"
        repo start $BR --all
        echo "ereport: `date` repo forall -c 'git branch'"
        repo forall -c "git branch"
        popd
    fi
}
create_repo_checkout_script()
{
    c2androiddir=$1
    BR=$2
    checkout_script=$3

    pushd $c2androiddir
    #create checkout script of this build code
    echo '#!/bin/sh'                 >$checkout_script
    echo ""                         >>$checkout_script
    echo "repo start --all $BR"     >>$checkout_script
    echo ""                         >>$checkout_script
    repo forall -c "echo pushd \$(pwd);
        echo -en 'git checkout ';
        git  log -n 1 | grep ^commit\ | sed 's/commit //g';
        echo 'popd'; echo ' ';" >>$checkout_script
    sed -i -e "s,$c2androiddir/,,g"   $checkout_script
    chmod 755                         $checkout_script
    popd
}

checkadd_fail_send_list()
{
    blame_devtools="saladwang hguo"
    blame_sw_media="jliu fzhang czheng kkuang summychen weli thang bcang lji qunyingli  codec_sw"
    blame_qt="mxia dashanzhou txiang slu jzhang                                         sw_apps"
    blame_c2box="mxia dashanzhou txiang slu jzhang                                      sw_apps"
    blame_jtag="jsun"
    blame_c2_goodies="jsun robinlee ali"
    blame_diag="jsun"
    blame_kernel="jsun robinlee ali roger llian simongao xingeng swine hguo janetliu    sys_sw"
    blame_vivante="llian jsun"
    blame_hdmi="jsun xingeng"
    blame_uboot="ali jsun robinlee"
    blame_facudisk="hguo"
    blame_usrudisk="hguo"
    blame_xxx="hguo"

    #pickup the fail log's tail to email for a quick preview
    loglist=`cat $CONFIG_INDEXLOG`
    nr_failmodule=0
    for i in $loglist ; do
        m=`echo $i | sed 's,\([^:]*\).*,\1,'`
        x=`echo $i | sed 's,[^:]*:\([^:]*\).*,\1,'`
        f=`echo $i | sed 's,[^:]*:[^:]*:\([^:]*\).*,\1,'`
        l=`echo $f | sed 's:.*/\(.*\):\1:'`
        if [ $x -ne 0 ]; then
	    addto_resultfail $m
	    nr_failmodule=$(($nr_failmodule+1))
            case $m in
            devtools*    ) addto_send $blame_devtools   ;;
            sw_media*    ) addto_send $blame_sw_media   ;;
            qt*          ) addto_send $blame_qt         ;;
            c2box*       ) addto_send $blame_c2box      ;;
            jtag*        ) addto_send $blame_jtag       ;;
            c2_goodies*  ) addto_send $blame_c2_goodies ;;
            diag*        ) addto_send $blame_diag       ;;
            kernel*      ) addto_send $blame_kernel     ;;
            vivante*     ) addto_send $blame_vivante    ;;
            hdmi*        ) addto_send $blame_hdmi       ;;
            uboot*       ) addto_send $blame_uboot      ;;
            facudisk*    ) addto_send $blame_facudisk   ;;
            usrudisk*    ) addto_send $blame_usrudisk   ;;
            xxx*         ) addto_send $blame_xxx        ;;
            *)  	  ;;
            esac
        fi
    done
    [ $nr_failmodule -gt 0 ] && addto_send robinlee@c2micro.com
}

list_fail_url_tail()
{
    #pickup the fail log's tail to email for a quick preview
    nr_failurl=0
    loglist=`cat $CONFIG_INDEXLOG`
    for i in $loglist ; do
        m=`echo $i | sed 's,\([^:]*\).*,\1,'`
        x=`echo $i | sed 's,[^:]*:\([^:]*\).*,\1,'`
        f=`echo $i | sed 's,[^:]*:[^:]*:\([^:]*\).*,\1,'`
        l=`echo $f | sed 's:.*/\(.*\):\1:'`
        if [ $x -ne 0 ]; then
            nr_failurl=$((nr_failurl+1))
            case $m in
            *_udisk) #jump these
                ;;
            *)
                echo $m fail :
		echo -en "    "
                echo "$SDKENV_URLPRE/${CONFIG_LOGSERVER##*/}/$l"
                ;;
            esac
        fi
    done
    for i in $loglist ; do
        m=`echo $i | sed 's,\([^:]*\).*,\1,'`
        x=`echo $i | sed 's,[^:]*:\([^:]*\).*,\1,'`
        f=`echo $i | sed 's,[^:]*:[^:]*:\([^:]*\).*,\1,'`
        l=`echo $f | sed 's:.*/\(.*\):\1:'`
        if [ $x -ne 0 ]; then
            case $m in
            *_udisk) #jump these
                ;;
            *)
                echo
                echo $m fail , tail of $l:
                tail -n 40 $f
                ;;
            esac
        fi
    done
    export nr_failurl
}

generate_web_report()
{
#set | grep CONFIG_ | sed -e 's/'\''//g' -e 's/'\"'//g' -e 's/ \+/ /g' >$CONFIG_LOGDIR/env.sh;
#generate web report
#these exports are used by html_generate.cgi
export SDK_RESULTS_DIR=${CONFIG_RESULT%/*}
export SDKENV_Title=$CONFIG_WEBTITLE
export SDKENV_Project="${CONFIG_ARCH} ${CONFIG_TREEPREFIX} daily build on $HOSTNAME"
export SDKENV_Overview="<pre>Project start on $CONFIG_STARTTIME, report on `date`
`recho_time_consumed $CONFIG_STARTTID On report time:`</pre>"
export SDKENV_Setting="<pre>Makefile settings:
`make -f $CONFIG_MAKEFILE lsvar`

build script settings:
`cat $CONFIG_LOGDIR/env.sh`
</pre>"
export SDKENV_Server="`whoami` on $CONFIG_MYIP(`hostname`)"
export SDKENV_Script="`readlink -f $0`"
export SDKENV_URLPRE=http://`echo ${CONFIG_LOGSERVER%/*} | sed -e 's,/var/www/html,,g' -e 's,^.*@,,g'`
export SDKENV_URLPRE=${SDKENV_URLPRE##*/}
$CONFIG_GENHTML  > $CONFIG_HTMLFILE
}

generate_email()
{
  #addto_send hguo@c2micro.com
  CONFIG_EMAILTITLE="${CONFIG_ARCH} $CONFIG_TREEPREFIX $HOSTNAME $nr_totalmodule module(s) $nr_totalerror error(s)."
  (
    echo "$CONFIG_EMAILTITLE"
    echo ""
    echo "Get build package at one of these nfs service:"
    for i in $CONFIG_PKGSERVERS; do
        [ "${i:0:1}" = "#" ] && continue; #comment line, invalid
	echo "    ${i##*@}"
    done
    echo ""
    [ $FAILLIST_BUILD            ] && echo "fail in this build: $FAILLIST_BUILD"
    [ $FAILLIST_RESULT    ] && echo "fail in all builds: $FAILLIST_RESULT"
    echo "Click one of these to watch report:"
    for i in  $CONFIG_WEBSERVERS; do
        [ "${i:0:1}" = "#" ] && continue; #comment line, invalid
        echo $i | grep "10.0.5" >/dev/null; #SJ server
        if [ $? -eq 0  ]; then
            u=`echo "${i##*/home/}" | sed 's,/public_html/.*,,g'`
	    echo -en "    https://access.c2micro.com/~$u"
            echo "${i##*/public_html}"
        else
	    echo -en "    http://"
            echo "${i##*@}" | sed 's,:/var/www/html,,g'
        fi
    done
    echo "Click one of these to watch logs:"
    for i in $CONFIG_LOGSERVERS; do
        [ "${i:0:1}" = "#" ] && continue; #comment line, invalid
        echo $i | grep "10.0.5" >/dev/null; #SJ server
        if [ $? -eq 0  ]; then
            u=`echo "${i##*/home/}" | sed 's,/public_html/.*,,g'`
	    echo -en "    https://access.c2micro.com/~$u"
            echo "${i##*/public_html}"
        else
	    echo -en "    http://"
            echo "${i##*@}" | sed 's,:/var/www/html,,g'
        fi
    done
    list_fail_url_tail
    echo ""
    echo "More build environment reference info:"
    make -f $CONFIG_MAKEFILE lsvar
    echo ""
    echo "send to list: $CONFIG_MAILLIST"
    echo "You receive this email because you are in the relative software maintainer list"
    echo "For more other request about this email, please send contact with me"
    echo ""
    echo "For more reports: http://10.16.13.196/build/allinone.htm"
    echo "    or https://access.c2micro.com/~build/allinone.htm"
    #echo "Check broken log history:  http://10.16.13.196/${USER}/blog"
    echo ""
    echo "Regards,"
    echo "`whoami`,`hostname`($CONFIG_MYIP)"
    echo "`readlink -f $0`"
    date
  ) >$CONFIG_EMAILFILE 2>&1
}

upload_web_report()
{
  if [ $CONFIG_BUILD_PUBLISHHTML ]; then
    for sver in $CONFIG_WEBSERVERS; do
        [ "${sver:0:1}" = "#" ] && continue; #comment line, invalid
        h=${sver%%:/*}
        p=${sver##*:}
	f=${p##*/}
	p=${p%/*}
        ip=`echo $sver | sed -e 's,.*@\(.*\):.*,\1,g'`
	if [ "$ip" = "$CONFIG_MYIP" ];then
            mkdir -p $p
            echo "cp -f $CONFIG_HTMLFILE $p/$f"
            cp -f $CONFIG_HTMLFILE $p/$f
        else
            ssh $h mkdir -p $p
	    echo "scp -r $CONFIG_HTMLFILE $sver"
	    scp -r $CONFIG_HTMLFILE $sver
        fi
    done
    echo publish web done.
  fi
}

upload_logs()
{
  if [ $CONFIG_BUILD_PUBLISHLOG ]; then
    unix2dos -q $CONFIG_LOGDIR/*
    for sver in $CONFIG_LOGSERVERS; do
        [ "${sver:0:1}" = "#" ] && continue; #comment line, invalid
        h=${sver%%:/*}
        p=${sver##*:}
        ip=`echo $sver | sed -e 's,.*@\(.*\):.*,\1,g'`
	if [ "$ip" = "$CONFIG_MYIP" ];then
            mkdir -p $p
            if [ $# -gt 0 ]; then
	       echo "cp -rf $@ $p/"
	       cp -rf $@ $p/
            else
	       echo "cp -rf $CONFIG_LOGDIR/* $p/"
	       cp -rf $CONFIG_LOGDIR/* $p/
            fi
	else
            ssh $h mkdir -p $p
            if [ $# -gt 0 ]; then
	       echo "scp -r $@ $sver/"
	       scp -r $@ $sver/
            else
	       echo "scp -r $CONFIG_LOGDIR/* $sver/"
	       scp -r $CONFIG_LOGDIR/* $sver/
            fi
	fi
    done
    echo publish log done.
  fi
}

upload_packages()
{
    SDK_VERSION_ALL=`make -f $CONFIG_MAKEFILE SDK_VERSION_ALL`
    if [ $CONFIG_BUILD_PUBLISH ]; then
        for sver in $CONFIG_PKGSERVERS; do
            [ "${sver:0:1}" = "#" ] && continue; #comment line, invalid
            h=${sver%%:/*}
            p=${sver##*:}
            ip=`echo $sver | sed -e 's,.*@\(.*\):.*,\1,g'`
            if [ "$ip" = "$CONFIG_MYIP" ];then
                mkdir -p $p/c2sdk-${CONFIG_DATEH}
                echo "cp -rf $CONFIG_PKGDIR/*${CONFIG_DATEH}* $p/"
                cp -rf $CONFIG_PKGDIR/*${CONFIG_DATEH}* $p/
                cp -rf $CONFIG_PKGDIR/c2-$SDK_VERSION_ALL-*.tar.gz $p/c2sdk-${CONFIG_DATEH}/
                cp $CONFIG_PKGDIR/$CONFIG_CHECKOUT_C2SDK   $p/c2sdk-${CONFIG_DATEH}/
                cp $CONFIG_PKGDIR/$CONFIG_CHECKOUT_ANDROID $p/c2sdk-${CONFIG_DATEH}/
            else
                ssh $h mkdir -p $p/c2sdk-${CONFIG_DATEH}
                echo "scp -r $CONFIG_PKGDIR/*${CONFIG_DATEH}* $sver/"
                scp -r $CONFIG_PKGDIR/*${CONFIG_DATEH}* $sver/
                scp -r $CONFIG_PKGDIR/c2-$SDK_VERSION_ALL-*.tar.gz $sver/c2sdk-${CONFIG_DATEH}/
                scp -r $CONFIG_PKGDIR/$CONFIG_CHECKOUT_C2SDK       $sver/c2sdk-${CONFIG_DATEH}/
                scp -r $CONFIG_PKGDIR/$CONFIG_CHECKOUT_ANDROID     $sver/c2sdk-${CONFIG_DATEH}/
            fi
        done
        echo publish package done.
    fi
}

upload_install_sw_media()
{
    PKG_NAME_BIN_SW_MEDIA=c2-`make -f $CONFIG_MAKEFILE SDK_VERSION_ALL`-sw_media-bin.tar.gz
    #this only appears in ssh, no local enabled.
    if [ $CONFIG_BUILD_PUBLISHC2LOCAL ]; then
        for sver in $CONFIG_C2LOCALSERVERS; do
            [ "${sver:0:1}" = "#" ] && continue; #comment line, invalid
            h=${sver%%:/*}
            p=${sver##*:}
            ip=`echo $sver | sed -e 's,.*@\(.*\):.*,\1,g'`
            if [ "$ip" = "$CONFIG_MYIP" ];then
                echo "do nothing"
            else
                ssh $h mkdir -p $p
                echo "scp -r $CONFIG_PKGDIR/${PKG_NAME_BIN_SW_MEDIA} $sver/"
                scp -r $CONFIG_PKGDIR/${PKG_NAME_BIN_SW_MEDIA} $sver/
                ssh $h "cd $p; tar xzf ${PKG_NAME_BIN_SW_MEDIA}; rm ${PKG_NAME_BIN_SW_MEDIA};"
                scp $CONFIG_PKGDIR/$CONFIG_CHECKOUT_C2SDK  $sver/TARGET_LINUX_C2_JAZZ2T_RELEASE/
                ssh $h "cd $p; chmod -R g+w *"
                if test -d $p/TARGET_LINUX_C2_JAZZ2T_RELEASE/bin -a -d $p/TARGET_LINUX_C2_TANGO_RELEASE/bin; then
                    ssh $h  "cd ${p%/*}; rm daily-android; ln -s ${p##*/}  daily-android;"
                fi
            fi
        done
    fi
    echo publish sw_media package to ${p%/*} done.
}

send_email()
{
    echo email title "$CONFIG_EMAILTITLE"
    if [ $CONFIG_BUILD_PUBLISHEMAIL ]; then
        echo "send to: $CONFIG_MAILLIST"
        cat $CONFIG_EMAILFILE | mail -s"$CONFIG_EMAILTITLE" $CONFIG_MAILLIST
    else
        echo "send to: hguo@c2micro.com(for test only)"
        cat $CONFIG_EMAILFILE | mail -s"$CONFIG_EMAILTITLE" hguo@c2micro.com
    fi
    echo send mail done.
}

#set -ex
nr_failurl=0          #set in list_fail_url_tail
nr_totalerror=0       #set in build_modules_x_steps
nr_totalmodule=0      #set in nr_totalmodule
tm_total=`date +%s`   #for time stat
modules=xxx           #for place holder
steps=help            #for place holder
build_modules_x_steps()
{
    for xmod in ${modules}; do
        nr_merr=0
        tm_module=`date +%s`

        #let web know this module is in "doing" status:2
        update_indexlog "$xmod:2:$CONFIG_LOGDIR/$xmod.log" $CONFIG_INDEXLOG
        generate_web_report
        upload_web_report

        for s in ${steps}; do
            iserror=0
            echo -en `date +"%Y-%m-%d %H:%M:%S"` build ${s}_$xmod " "
            tm_a=`date +%s`
            echo `date +"%Y-%m-%d %H:%M:%S"` Start build  ${s}_$xmod >>$CONFIG_LOGDIR/progress.log
            make -f $CONFIG_MAKEFILE ${s}_$xmod        >>$CONFIG_LOGDIR/$xmod.log 2>&1
            if [ $? -ne 0 ];then
                nr_merr=$((nr_merr+1))
                iserror=$((iserror+1))
            fi
            echo `date +"%Y-%m-%d %H:%M:%S"` Done build  ${s}_$xmod, $nr_merr error >>$CONFIG_LOGDIR/progress.log
            recho_time_consumed $tm_a "$s: $iserror error(s). "
            if [ $nr_merr -ne 0 ];then
                break;
            fi
        done
        if [ $nr_merr -ne 0 ];then
            addto_buildfail $xmod
            upload_logs $CONFIG_LOGDIR/$xmod.log
        fi
        nr_totalerror=$((nr_totalerror+nr_merr))
        nr_totalmodule=$((nr_totalmodule+1))
        update_indexlog "$xmod:$nr_merr:$CONFIG_LOGDIR/$xmod.log" $CONFIG_INDEXLOG

        echo recho_time_consumed $tm_module "Build module $xmod $nr_merr error(s). "
        echo "    "
    done
}

setup_build_sw_media_for_android_env_jazz2()
{
    [ -d android ] || echo "Error, no android project folder found"
    export ANDROID_HOME=`readlink -f android`
    export ANDROID_BUILD=1
    #next added by Ben Cang.
    export UPNP_SUPPORT=1
    export D_EN_RTP=Y
    #next added by Westwood
    export PATH=$CONFIG_C2GCC_PATH:$PATH
    export TARGET_ARCH=TANGO;
    export BUILD_TARGET=TARGET_LINUX_C2;
    export BUILD=RELEASE;
    export BOARD_TARGET=C2_CC289; #add this for safe build jazz2-android-sw_media
}

setup_build_sw_media_for_android_env_jazz2t()
{
    [ -d android ] || echo "Error, no android project folder found"
    export ANDROID_HOME=`readlink -f android`
    export ANDROID_BUILD=1
    #next added by Ben Cang.
    export UPNP_SUPPORT=1
    export D_EN_RTP=Y
    #next added by Westwood
    export PATH=$CONFIG_C2GCC_PATH:$PATH
    export TARGET_ARCH=JAZZ2T;
    export BUILD_TARGET=TARGET_LINUX_C2;
    export BUILD=RELEASE;
    export BOARD_TARGET=C2_CC302; #add this for safe build jazz2t-android-sw_media
}

# let's go!
#---------------------------------------------------------------
lock_job
make -f $CONFIG_MAKEFILE sdk_folders
mkdir -p $CONFIG_RESULT $CONFIG_LOGDIR
touch $CONFIG_INDEXLOG
touch $CONFIG_HTMLFILE
touch $CONFIG_EMAILFILE
softlink $CONFIG_INDEXLOG r
softlink $CONFIG_LOGDIR   l
softlink $CONFIG_RESULT   i
#action parse
set | grep CONFIG_ | sed -e 's/'\''//g' -e 's/'\"'//g' -e 's/ \+/ /g' >$CONFIG_LOGDIR/env.sh;
cat $CONFIG_LOGDIR/env.sh
checkout_from_repositories
create_repo_checkout_script `readlink -f source`  $CONFIG_BRANCH_C2SDK   $CONFIG_PKGDIR/$CONFIG_CHECKOUT_C2SDK
create_repo_checkout_script `readlink -f android` $CONFIG_BRANCH_ANDROID $CONFIG_PKGDIR/$CONFIG_CHECKOUT_ANDROID

if [ $CONFIG_BUILD_SWMEDIA ]; then
    [ -h local.rules.mk ] && rm local.rules.mk
    ln -s jazz2t.rules.mk local.rules.mk
    modules="sw_mediaandroid"
    steps="src_get src_package src_install src_config src_build bin_package bin_install "
    setup_build_sw_media_for_android_env_jazz2t
    build_modules_x_steps

    r=`grep ^sw_mediaandroid:0 $CONFIG_INDEXLOG`
    if [ "$r" != "" ]; then
        rm -rf android/prebuilt/sw_media
        mkdir -p android/prebuilt/sw_media
        tar xzf $CONFIG_PKGDIR/c2-*-sw_media*bin*.tar.gz -C android/prebuilt/sw_media
        sed -i "s,SW_MEDIA_PATH=.*,SW_MEDIA_PATH=`readlink -f android/prebuilt/sw_media`,g"   android/env.sh
        echo `date +"%Y-%m-%d %H:%M:%S"` sw_media: modify android using prebuilt/sw_media >>$CONFIG_LOGDIR/progress.log
    else
	rm android/env.sh
        echo `date +"%Y-%m-%d %H:%M:%S"` sw_media: reset android env.sh >>$CONFIG_LOGDIR/progress.log
    fi
fi

if [ $CONFIG_BUILD_UBOOT ]; then
    modules="uboot"
    steps="src_get src_package src_install src_config src_build bin_package bin_install "
    build_modules_x_steps
fi

if [ $CONFIG_BUILD_ANDROIDNFS ]; then
    xmod=nfsdroid
    update_indexlog "$xmod:2:$CONFIG_LOGDIR/$xmod.log" $CONFIG_INDEXLOG
    generate_web_report
    upload_web_report

    echo `date +"%Y-%m-%d %H:%M:%S"` Start build  $xmod >>$CONFIG_LOGDIR/progress.log
    tm_a=`date +%s`
    cp android/build/tools/make-nfs-droid-fs-usr $CONFIG_LOGDIR/
    sed -i 's/sudo//g' $CONFIG_LOGDIR/make-nfs-droid-fs-usr

    cd `readlink -f android`
    cmd_opt=
    if [ $CONFIG_BUILD_CLEAN ]; then
        mkdir -p nfs-droid
        rm -rf nfs-droid/*
        cmd_opt="-m -f"
    fi
    [ "$CONFIG_ARCH" == "jazz2t" ] && cmd_opt="$cmd_opt -t jazz2t"
    $CONFIG_LOGDIR/make-nfs-droid-fs-usr  $cmd_opt   >$CONFIG_LOGDIR/$xmod.log 2>&1
    cp -f build/tools/gen-nfs-burn-code.sh nfs-droid/
    cp $CONFIG_PKGDIR/$CONFIG_CHECKOUT_C2SDK   nfs-droid/
    cp $CONFIG_PKGDIR/$CONFIG_CHECKOUT_ANDROID nfs-droid/
    tar czf $CONFIG_PKGDIR/c2-$CONFIG_ARCH-$CONFIG_BRANCH_ANDROID.$CONFIG_DATEH-nfs-droid.tar.gz nfs-droid

    cd $TOP
    echo `date +"%Y-%m-%d %H:%M:%S"` Done build  $xmod, 0 error >>$CONFIG_LOGDIR/progress.log
    recho_time_consumed $tm_a "The repo build $xmod"
    update_indexlog "$xmod:0:$CONFIG_LOGDIR/$xmod.log" $CONFIG_INDEXLOG
    #check build result
    #package build files
    nr_totalmodule=$((nr_totalmodule))
    #nr_totalerror=$((nr_totalerror+1))
fi

if [ $CONFIG_BUILD_ANDROIDNAND ]; then
    xmod=nanddroid
    update_indexlog "$xmod:2:$CONFIG_LOGDIR/$xmod.log" $CONFIG_INDEXLOG
    generate_web_report
    upload_web_report

    echo `date +"%Y-%m-%d %H:%M:%S"` Start build  $xmod >>$CONFIG_LOGDIR/progress.log
    tm_a=`date +%s`
    cp android/build/tools/make-nand-droid-fs $CONFIG_LOGDIR/
    sed -i 's/sudo//g' $CONFIG_LOGDIR/make-nand-droid-fs

    cd `readlink -f android`
    cmd_opt=
    if [ $CONFIG_BUILD_CLEAN ]; then
        mkdir -p nand-droid
        rm -rf nand-droid/*
    fi
    [ "$CONFIG_ARCH" == "jazz2t" ] && cmd_opt="$cmd_opt -t jazz2t"
    $CONFIG_LOGDIR/make-nand-droid-fs  $cmd_opt   >$CONFIG_LOGDIR/$xmod.log 2>&1
    cp -f build/tools/gen-uboot-burn-code.sh  nand-droid/
    cp -f kernel/vmlinux.bin                  nand-droid/
    cat <<END >>nand-droid/run

NAND burn guide:
burn zvmlinux.bin ->NAND +  1MB
burn root.image   ->NAND + 16MB
burn system.image ->NAND +112MB
burn data.image   ->NAND +368MB

ref c2 wiki: https://access.c2micro.com/index.php/Android#Local_build_and_driver_update

END
    cp $CONFIG_PKGDIR/$CONFIG_CHECKOUT_C2SDK   nand-droid/
    cp $CONFIG_PKGDIR/$CONFIG_CHECKOUT_ANDROID nand-droid/
    mkdir -p $CONFIG_PKGDIR/nand-droid-$CONFIG_DATEH
    cp -rf nand-droid/* $CONFIG_PKGDIR/nand-droid-$CONFIG_DATEH/

    cd $TOP
    echo `date +"%Y-%m-%d %H:%M:%S"` Done build  $xmod, 0 error >>$CONFIG_LOGDIR/progress.log
    recho_time_consumed $tm_a "The repo build $xmod"
    if [ -f android/nand-droid/root.image -a -f android/nand-droid/system.image -a -f android/nand-droid/data.image ]; then
        build_fail=
        update_indexlog "nfsdroid:0:$CONFIG_LOGDIR/nfsdroid.log" $CONFIG_INDEXLOG
        update_indexlog "$xmod:0:$CONFIG_LOGDIR/$xmod.log" $CONFIG_INDEXLOG
    else
        CONFIG_BUILD_PUBLISH=
        build_fail="yes"
        update_indexlog "nfsdroid:1:$CONFIG_LOGDIR/nfsdroid.log" $CONFIG_INDEXLOG
        update_indexlog "$xmod:1:$CONFIG_LOGDIR/$xmod.log" $CONFIG_INDEXLOG
        nr_totalerror=$((nr_totalerror+1))
        nr_totalerror=$((nr_totalerror+1))
    fi
    #check build result
    #package build files
    nr_totalmodule=$((nr_totalmodule))
fi

modules=
[ $CONFIG_BUILD_FACUDISK ] && modules="$modules facudisk"
[ $CONFIG_BUILD_USRUDISK ] && modules="$modules usrudisk"
steps="src_get src_package src_install src_config src_build bin_package bin_install "
if [ "$modules" != "" ]; then
    dep_fail=0
    r=`grep ^c2box:0 $CONFIG_INDEXLOG`
    j=`grep ^uboot:0 $CONFIG_INDEXLOG`
    k=`grep ^kernel:0 $CONFIG_INDEXLOG`
    [ "$r" = "" ] && dep_fail=$((dep_fail+1))
    [ "$j" = "" ] && dep_fail=$((dep_fail+1))
    [ "$k" = "" ] && dep_fail=$((dep_fail+1))
    if [ $dep_fail -eq 0 ]; then
        build_modules_x_steps
    else
        echo can not build facudisk or usrudisk, depend steps: c2box uboot kernel
    fi
fi

if [ $CONFIG_BUILD_XXX ]; then  #script debug code
    modules="xxx"
    #modules="devtools sw_media qt470 kernel kernelnand kernela2632 uboot vivante hdmi c2box jtag diag c2_goodies facudisk usrudisk"
    steps="src_get src_package src_install src_config src_build bin_package bin_install "
    build_modules_x_steps
fi

checkadd_fail_send_list
[ $nr_failurl    -gt 0 ] && CONFIG_BUILD_PUBLISH=
[ $nr_totalerror -gt 0 ] && CONFIG_BUILD_PUBLISH=
generate_web_report
generate_email
upload_web_report
upload_packages
upload_logs
send_email
upload_install_sw_media
unlock_job
