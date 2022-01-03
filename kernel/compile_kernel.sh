#!/bin/bash

if [ "$#" -ne 1 ]; then
	echo "Usage: ./compile_kernel.sh <num_threads>"
	exit 1
fi

script_file=`readlink $0`
script_path=`dirname ${script_file}`
threads=$1

set -x

ksrc_path=`readlink ${script_path}/linux-5.4`

# Go to kernel src path
cd $ksrc_path

make mrproper
rm -rf debian
rm -f vmlinux-gdb.py

make menuconfig
scripts/config --set-str SYSTEM_TRUSTED_KEYS ""
make -j$(threads) LOCALVERSION=-91-splitfs KDEB_PKGVERSION=1.splitfs deb-pkg
