#!/bin/sh

bootargs="mem=512m,128m,64m console=ttyS0 video=c2fb:cpnt,720p,60,fbcm:16M root=/dev/mtdblock1 rw rootfstype=yaffs2 ip=dhcp init=/init mtdparts=c2nfc:16M(boot),96M(root),192M(system),64M(cache),128M(userdata)"

mac="00:E0:c3:00:01:02"
ip="10.16.5.168"
mask=`/sbin/ifconfig eth0 | grep 'inet addr' | sed 's/.* Mask:\(.*\)/\1/'`
THISIP=`/sbin/ifconfig eth0 | grep 'inet addr' | sed 's/.*addr:\(.*\)\(  Bcast.*\)/\1/'`
loadaddr=0xa0000000
nandesize=4127518
nfsroot=`pwd`
detectsize=1
brief=1

help()
{
    cat <<-EOF >&2

    usage: ./${0##*/} [ option ] [ Board IP set ]

    option:
    -a  auto detect file size enabled(default)
    -A  auto detect file size disabled
    -b  brief mode enabled(default)
    -B  brief mode disabled

    Board IP set:
    -ip<IP> set target board IP address

    Auto set:
    Server IP: using localmachine IP
    nfsroot folder: using current pwd.

    example ./${0##*/} -ip10.16.5.189

    Notice:
    if zvmlinux.bin does not work(decompress.. and hang up),
    please try vmlinux.bin as a workaround solution.

    Create u-boot burn code to target board script reference
    C2 microsystems, BJ. 2011. by hguo@.

	EOF
}

while [ $# -gt 0 ]; do
    case $1 in
    -a)   detectsize=1;      shift ;;
    -A)   detectsize=0;      shift ;;
    -b)   brief=1;      shift ;;
    -B)   brief=0;      shift ;;
    -ip*) ip="${1#-ip}";     shift ;;
    *)    help;	exit 0  ;;
    esac
done
nand_write_from_nfs()
{
    # $1 nand address
    # $2 nand size
    # $3 ram  address
    # $4 src url
    if [ ! -f $4 -a $detectsize -eq 1 ]; then
        echo can not find file $4
        return 1;
    fi
    cmd=write
    case $4 in
        *.image) cmd=write.yaffs; 
    esac
    sizeHex=$2
    if [ $detectsize -eq 1 ]; then
      size=`stat -c %s $4`
      sizeM=$(((nandesize+`stat -c %s $4`)/1048576))
      sizeMB=$(((nandesize+`stat -c %s $4`)/1048576*1048576))
      sizeHex="0x`echo "obase=16; $sizeMB" | bc`"
      echo ""
      echo "file $4 $size bytes(use $sizeM MB, $sizeMB bytes, $sizeHex)."
    fi
    if [ $brief -eq 1 ]; then
cat <<BECODE
mw.b $3 0xff $sizeHex;set bootfile $4;nfs;
nand $cmd $3 $1 $sizeHex;
BECODE
    else
cat <<ECODE
set loadaddr $3;mw.b $3 0xff $sizeHex;set bootfile $4;nfs;
nand device 0;nand erase $1 $sizeHex;nand $cmd $3 $1 $sizeHex;
ECODE
    fi
}

cat <<EBASE

U-BOOT code for burning android nand system to platform.
Change network setting to your sytem before using it.
    c2 microsystems, `date`
-------------------------------------------------------

setenv macaddr $mac;setenv ethaddr $mac;setenv netmask $mask;
setenv serverip $THISIP;setenv ipaddr $ip; setenv gatewayip ${ip%.*}.1
setenv loadaddr $loadaddr

set bootargs $bootargs;
setenv bootcmd 'nand device 0;nand read $loadaddr 0x00100000 0x900000;go'

nand device 0; nand scrub
nand device 0; nand erase
EBASE
#                         from      size   ram-from file
nand_write_from_nfs   0x100000  0x900000 $loadaddr $nfsroot/zvmlinux.bin
nand_write_from_nfs   0x100000  0x900000 $loadaddr $nfsroot/vmlinux.bin
nand_write_from_nfs  0x1000000 0x5800000 $loadaddr $nfsroot/root.image
nand_write_from_nfs  0x7000000 0xB000000 $loadaddr $nfsroot/system.image
nand_write_from_nfs 0x17000000  0xC00000 $loadaddr $nfsroot/data.image

echo ""
