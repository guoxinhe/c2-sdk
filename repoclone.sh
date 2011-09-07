#!/bin/sh

BR=${1:-devel}
mf=${2:-default.xml}

if [ ! -d .repo ]; then
mkdir -p .repo; git clone ssh://git.bj.c2micro.com/mentor-mirror/build/repo.git .repo/repo
fi

if [ -d .repo/manifests ]; then
repo start $BR --all
else
yes "" | repo init -u ssh://git.bj.c2micro.com/mentor-mirror/build/manifests.git -b $BR -m $mf
fi
repo sync
repo start $BR --all
