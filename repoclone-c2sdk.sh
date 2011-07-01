#!/bin/sh

if [ ! -d .repo ]; then
#this will create .repo/repo
mkdir -p .repo;
pushd .repo;
git clone ssh://git.bj.c2micro.com/c2sdk/repo.git;
popd;
fi

if [ ! -d .repo/manifests ]; then
#this will create in .repo/ manifest.xml  manifests  manifests.git 
repo init -u ssh://git.bj.c2micro.com/c2sdk/manifests.git
echo please restart this command to sync all data.
echo this second time will run a long time download data.
echo suggest put to a background task.
exit 0
fi

if [ -f .repo/project.list ]; then
#after run the first time repo sync, exit this file
repo start master --all
fi

repo sync
repo start master --all
