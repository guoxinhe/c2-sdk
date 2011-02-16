#!/bin/sh

SDK_TARGET_ARCH=jazz2
MAJOR=1
MINOR=0
BRANCH=1
TAGVER=${1-6}

CANDIDATE=${BRANCH}-${TAGVER}
CVS_TAG=${SDK_TARGET_ARCH}-SDK-${MAJOR}_${MINOR}-${CANDIDATE}
SDK_VERSION_ALL=$SDK_TARGET_ARCH-sdk-${MAJOR}.${MINOR}-${CANDIDATE}
TREE_PREFIX=msp_rel           #used by create html script
CONFIG_BUILD_DOTAG=1
BUILD_DIR=/build/$SDK_TARGET_ARCH/rel
CVSTAG_DIR=$BUILD_DIR/tag
DIST_DIR=/build/$SDK_TARGET_ARCH/rel/build_result
S200_DIR=/sdk/$SDK_TARGET_ARCH/rel/candidate/c2-$SDK_TARGET_ARCH-sdk-${MAJOR}.${MINOR}-${BRANCH}/${MAJOR}.${MINOR}-${CANDIDATE}
SDK_REMOTE_FOLDER=/home/hguo/maintreebranch




echo Using $S200_DIR/c2-${SDK_VERSION_ALL}-kernel-nand-bin.tar.gz  
echo Using $S200_DIR/c2box/c2-${SDK_VERSION_ALL}-c2box-bin.tar.gz 
rm -rf sw rootfs.image vmlinux vmlinux.dump vmlinux.bin zvmlinux.bin
rm -rf c2-${SDK_VERSION_ALL}-kernel-nand-bin.tar.gz c2-${SDK_VERSION_ALL}-c2box-bin.tar.gz
cp $S200_DIR/c2-${SDK_VERSION_ALL}-kernel-nand-bin.tar.gz . 
cp $S200_DIR/c2box/c2-${SDK_VERSION_ALL}-c2box-bin.tar.gz .
tar xzf c2-${SDK_VERSION_ALL}-kernel-nand-bin.tar.gz
cp sw/kernel/rootfs.image . 
cp sw/kernel/linux-2.6/zvmlinux.bin . 
cp sw/kernel/linux-2.6/vmlinux* . 

