#!/bin/sh

if [ ! -d .repo ]; then
mkdir -p .repo;
pushd .repo;
git clone ssh://git.bj.c2micro.com/c2sdk/repo.git;
popd;
fi

if [ -d .repo/manifests ]; then
repo start master --all
repo sync
repo start master --all
else
repo init -u ssh://git.bj.c2micro.com/c2sdk/manifests.git 
echo please restart this command to sync all data.
fi

