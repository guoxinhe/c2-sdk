#!/bin/sh

#goes to target folder and clone a repo from local, otherwise will from website.
if [ ! -d .repo ]; then
mkdir -p .repo;
pushd .repo;
git clone ssh://git.bj.c2micro.com/mentor-mirror/build/repo.git;
popd;
fi

BR=${1:-devel}

if [ -d .repo/manifests ]; then
repo start $BR --all
else
repo init -u ssh://git.bj.c2micro.com/mentor-mirror/build/manifests.git -b $BR
fi
repo sync
repo start $BR --all
