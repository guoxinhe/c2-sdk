#!/bin/sh

lzo_ver=lzo-2.04
lzo_pkg=$lzo_ver.tar.gz
lzo_url=http://www.oberhumer.com/opensource/lzo/download
lzo_dst=`pwd`/lzo
mkdir -p $lzo_dst
[ ! -f $lzo_pkg ] && wget  $lzo_url/$lzo_pkg
[ ! -d $lzo_ver ] && tar xzf $lzo_pkg
pushd $lzo_ver
./configure 
make
sudo make install
popd

mtd_url=git://git.infradead.org/mtd-utils.git
mtd_tmp=`pwd`
mkdir -p $mtd_tmp
pushd $mtd_tmp
[ ! -d mtd-utils ] && git clone $mtd_url 
pushd mtd-utils
make 
sudo make install
popd
popd
