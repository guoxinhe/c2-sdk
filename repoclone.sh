#!/bin/sh

BR=${1:-devel}
urlrepo=ssh://git.bj.c2micro.com/mentor-mirror/build/repo.git
urlmani=ssh://git.bj.c2micro.com/mentor-mirror/build/manifests.git
if [ ! -d .repo/repo ]; then
mkdir -p .repo;
pushd .repo;
git clone $urlrepo
popd;
fi

if [ ! -d .repo/manifests ]; then
repo init -u $urlmani -b $BR
fi

if [ -f .repo/project.list ]; then
repo start $BR --all
fi

repo sync
repo start $BR --all
