#!/bin/sh

SCRIPTPATH=`readlink -f $0`
SCRIPTPATH=${SCRIPTPATH%/*}
TOP=${SCRIPTPATH%/*}
PATH=$PATH:$SCRIPTPATH

DEBUG=true #echo #or true or false

projects="
proja/master/x86
proja/br010/x86
projb/master/x86
projb/br010/x86
";
send_fail_report_email()
{
    myti=$1
    update_id=$2

    if [ ! -d $TOP/$myti/build_result/$update_id ]; then
        return 0; #folder does not exist, cancel task.
    fi
}
checkout_target()
{
    demo=/local/gitbuilder/buildcheck/sandbox
    myti=$1
    $DEBUG "Debug on checkout $myti......";
    gitlog=$TOP/$myti/build_result/`date +%y%m%d`.git.log
    mkdir -p $TOP/$myti/build_result ${gitlog%/*}

    myproject=`echo $myti | awk -F"/" '{print $1}'`
    mybranch=` echo $myti | awk -F"/" '{print $2}'`
    mytarget=` echo $myti | awk -F"/" '{print $3}'`

    (
    if [ "$myproject" = "proja" -a "$mybranch" = "master" ]; then
        mkdir -p $TOP/$myti/source/.repo
        cd       $TOP/$myti/source/.repo
        git clone $demo/repo.git
        cd $TOP/$myti/source
        yes "" |  repo init -u $demo/manifests.git
        repo sync
        repo start $mybranch --all
        return 0
    fi

    if [ "$myproject" = "projb" -a "$mybranch" = "master" ]; then
        mkdir -p $TOP/$myti
        cd $TOP/$myti
        git clone $demo/hello.git source
        return 0
    fi
    ) >>$gitlog 2>&1
    echo "    do not know how to checkout task $myti's source code"
    return 0;
}
get_module_cosh()
{
    local mysrc=$1;
    local mycosh="$2";
    local mybranch="$3";
    local mydbg=
    shift 3;
    local project_list="$@";

    cd  $mysrc
    if [ "$project_list" = "" ]; then
        if [ -f .repo/project.list ]; then 
            project_list=`cat .repo/project.list`
        else
            if [ -d .git ]; then
                project_list="."
            else
                if [ "$mydbg" = "on" ]; then
                              find . -name \.git -type d | sed -e 's,/.git,,g' -e 's,^./,,g'
                fi
                project_list=`find . -name \.git -type d | sed -e 's,/.git,,g' -e 's,^./,,g'`
            fi
        fi
    fi
    if [ "$project_list" = "" ]; then
        return 0
    fi

    mkdir -p ${mycosh%/*}
    echo "#!/bin/sh"  >$mycosh
    echo "#autocreated script, checkout git by hash ids" >>$mycosh
    echo "#please update code and switch to target branch before run this" >>$mycosh
    echo "#branch name: $mybranch" >>$mycosh
    chmod 755 $mycosh
    for pi in $project_list; do
        cd $mysrc/$pi;
        id=`git log -n 1 | grep ^commit\ | sed 's/commit //g'`;
        pad="$pi";
        while [ ${#pad} -lt 20 ]; do
            pad="$pad ";
        done
        echo "pushd $pad; git checkout $id; popd" >>$mycosh
    done
}
get_module_coid()
{
    local mysrc=$1
    local mydbg=
    shift
    local project_list="$@"

    cd  $mysrc
    if [ "$project_list" = "" ]; then
        if [ -f .repo/project.list ]; then 
            project_list=`cat .repo/project.list`
        else
            if [ -d .git ]; then
                project_list="."
            else
                if [ "$mydbg" = "on" ]; then
                              find . -name \.git -type d | sed -e 's,/.git,,g' -e 's,^./,,g'
                fi
                project_list=`find . -name \.git -type d | sed -e 's,/.git,,g' -e 's,^./,,g'`
            fi
        fi
    fi
    if [ "$project_list" = "" ]; then
        echo -en "1000000000_10000000_1000000000000000000000000000000000000000"
        return 0
    fi

    new_revid=0;
    new_revts=0;
    new_revpt=".";
    for pi in $project_list; do
        cd $mysrc/$pi;
        revid=`git log -n 1 | grep ^commit\ | sed 's/commit //g'`;
        revts=`git log -n 1 --pretty=format:%ct`;
        if [ $revts -gt $new_revts ]; then
            new_revid=$revid
            new_revts=$revts
            new_revpt=$pi
        fi
    done
    revid=$new_revid;
    pathid=`echo $new_revpt | /usr/bin/md5sum | awk '{printf $1}'`00000000;
    update_id=${new_revts}_${pathid:0:8}_${revid};
    if [ "$mydbg" = "on" ]; then
        echo "The last check out id of module $mysrc is: $update_id"
    fi
    echo -en "$update_id"
}
update_target()
{
    myti=$1
    $DEBUG "Debug on update $myti......";
    gitlog=$TOP/$myti/build_result/`date +%y%m%d`.git.log
    mkdir -p $TOP/$myti/build_result ${gitlog%/*}

    br=` echo $myti | awk -F"/" '{print $2}'`
    cd  $TOP/$myti/source
    if [ -f .repo/repo/repo ]; then 
        (
        repo forall -c "git branch; git reset --hard; git clean -d -f -x;"
        repo start $br --all
        repo sync
        ) >>$gitlog 2>&1
    else
    if [ -d .git ]; then
        (
        git branch; git reset --hard; git clean -d -f -x;
        git checkout $br;
        git pull origin $br;
        ) >>$gitlog 2>&1
    fi
    fi
}
build_target()
{
    myti=$1
    $DEBUG "Debug on build $myti......";
    mkdir -p $TOP/$myti/build_result
    if [ ! -f $TOP/$myti/build_result/last_coid ]; then
        echo "    Error: can not find checkout id file $TOP/$myti/build_result/last_coid";
        return 0;
    fi
    update_id=`cat $TOP/$myti/build_result/last_coid`
    if [ ! -d $TOP/$myti/build_result/$update_id ]; then
        echo "    Error: can not find checkout id folder $TOP/$myti/build_result/$update_id";
        return 0;
    fi
    
    cd $TOP/$myti/build_result
    rm -rf fail pass result
    cp last_coid last_built   #a softlock for avoid rebuild
    cd $TOP/$myti/build_result/$update_id
    rm -rf fail pass result

    (
    cd $TOP/$myti
    if [ -f Makefile ]; then
        make $target
        build_ret=$?
    else
    if [ -x build.sh ]; then
        ./build.sh $target
        build_ret=$?
    else
        echo "    no build method detected."
        build_ret=1
    fi
    fi
    if [ $build_ret -eq 0 ]; then
        echo "pass" >$TOP/$myti/build_result/$update_id/result
        ln -s result $TOP/$myti/build_result/$update_id/pass
        ln -s coid_link/result  $TOP/$myti/build_result/pass
    else
        echo "fail" >$TOP/$myti/build_result/$update_id/result
        ln -s result $TOP/$myti/build_result/$update_id/fail
        ln -s coid_link/result  $TOP/$myti/build_result/fail
    fi
    )>$TOP/$myti/build_result/$update_id/log 2>&1

    if [ -h $TOP/$myti/build_result/$update_id/fail ]; then
        send_fail_report_email $myti $update_id
    fi
}
unlock_job()
{
  lock=$1
  rm -rf $lock.log #if exist, left for check, will be removed next lock
  rm -rf $lock
}
build_project()
{
    ti=$1
    echo "Debug on $ti......";
    project=`echo $ti | awk -F"/" '{print $1}'`
    branch=` echo $ti | awk -F"/" '{print $2}'`
    target=` echo $ti | awk -F"/" '{print $3}'`

    mkdir -p $TOP/$ti/build_result
    lock=$TOP/$ti/build.lock
    if test -f $lock ; then
    burn=`stat -c%Z $lock`
    now=`date +%s`
    age=$((now-burn))
    #24 hour = 86400 seconds = 24 * 60 * 60 seconds.
    if [ $age -gt 7200 ]; then
        unlock_job $lock
    else
        echo "an active task is running for $age seconds: `cat $lock`"
        echo "close it before restart: $lock"
        echo "`date` $(whoami)@$(hostname) `readlink -f $0` tid:$$, lock age: $age, life: $jobtimeout" >>$lock.log
        return 0;
    fi
    fi
    echo "`date` $(whoami)@$(hostname) `readlink -f $0` tid:$$ " >$lock

    if [ ! -d $TOP/$ti/source ]; then
        checkout_target $ti
    fi
    if [ ! -d $TOP/$ti/source ]; then
        #echo "No source code for project $project, branch $branch, target $target, please give checkout method."
        unlock_job $lock;
        return 0;
    fi

    update_target $ti
    update_id=`get_module_coid $TOP/$ti/source`
    if test -d $TOP/$myti/build_result/$update_id; then
        echo "    Code already up to date"
    else
        echo $update_id >$TOP/$myti/build_result/last_coid
        mkdir -p $TOP/$myti/build_result/$update_id
        [ -h $TOP/$myti/build_result/coid_link ] && rm $TOP/$myti/build_result/coid_link
        ln -s $update_id $TOP/$myti/build_result/coid_link
        get_module_cosh $TOP/$ti/source $TOP/$myti/build_result/$update_id/co $branch
    fi

    cd $TOP/$ti
    diff -q $TOP/$ti/build_result/last_coid $TOP/$ti/build_result/last_built >/dev/null 2>&1
    ret=$?
    case $ret in
    0)  $DEBUG "task $ti completed.";
        unlock_job $lock;
        return 0;
        ;; #both exist, same
    1)  build_target $ti
        ;; #both exist, differ: new code check in
    2)  build_target $ti
        ;; #one or both not exist: first time build
    *)  build_target $ti
        ;; #fall to an exception
    esac

    unlock_job $lock;
}
CONFIG_NRLOOP=1
while [ $# -gt 0 ] ; do
    case $1 in
    --loop)
       CONFIG_NRLOOP=$2; shift 2;;
    *) break;
    esac
done

if [ $# -gt 0 ] ; then
  pre=$1
  for ti in $projects; do
    case $ti in
    $pre*)  build_project $ti;;
    *)      $DEBUG found $ti matches $pre ;; #does not match
    esac
  done
else
  nr=0
  while [ $nr -lt $CONFIG_NRLOOP ]; do
      nr=$((nr+1));

      if test -f $TOP/bc.config ; then
          projects="`cat $TOP/bc.config`";
      fi
      if [ "$projects" = "" ]; then
          cd $TOP  #auto detect the project
          projects="`find . -name build_result -type d | sed -e s,$TOP/,,g -e s,/build_result,,g`"
      fi
      for ti in $projects; do
          build_project $ti
      done

  done
fi
