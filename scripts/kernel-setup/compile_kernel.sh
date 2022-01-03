#!/bin/bash

if [ "$#" -ne 1 ]; then
	echo "Usage: compile_kernel.sh <num_threads>"
	exit 1
fi	

threads=$1

set -x

src_path=`readlink -f ../../`
ksrc_path=${src_path}/kernel/linux-5.4

# Go to kernel build path
cd $ksrc_path

make mrproper
rm -rf debian
rm -f vmlinux-gdb.py

make menuconfig
scripts/config --set-str SYSTEM_TRUSTED_KEYS ""
make -j$(threads) KDEB_PKGVERSION=1.splitfs deb-pkg
