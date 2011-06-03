#!/bin/sh

BR=${1:-devel}

#goes to target folder and clone a repo from local, otherwise will from website.
if [ ! -d .repo ]; then
mkdir -p .repo; 
pushd .repo; 
git clone ssh://git.bj.c2micro.com/mentor-mirror/build/repo.git; 
popd;
fi

repo init -u ssh://git.bj.c2micro.com/mentor-mirror/build/manifests.git -b $BR
repo sync
repo start $BR --all
