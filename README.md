# SplitFS - Linux v5.4.0

This is a port of [SplitFS](https://github.com/utsaslab/SplitFS) to Linux kernel v5.4.0 for Ubuntu Focal 20.04.

Contents:

1. `kernel/`: source code of Linux kernel v5.4.0, with the relink operation added as `dynamic_remap` syscall at entry index `335` for `x86_64`
2. `splitfs/`: source code of SplitFS
3. `tests/`: PJD Posix FS test suite
4. `micro/`: a simple toy microbenchmark

---

## Dependencies

Required packages for kernel build and splitfs:

```bash
sudo apt update
sudo apt install libelf-dev libncurses5-dev bc libboost-dev
```

## Build & Install Kernel

Build and install kernel deb packages (when menuconfig pops up, tweak any options as desired, or simply save & exit):

```bash
cd kernel
./compile_kernel.sh <num_threads>
sudo dpkg -i linux-*.deb
```

Check installed kernel's GRUB menu entry:

```bash
awk -F\' '$1=="menuentry " || $1=="submenu " {print i++ " : " $2}; /\tmenuentry / {print "\t" i-1">"j++ " : " $2};' /boot/grub/grub.cfg
```

Change GRUB config to boot into installed kernel:

```bash
sudo vim /etc/default/grub
    # Say new kernel at 1>4, change to GRUB_DEFAULT="1>4"
    # If emulating pmem device with DRAM, add `memmap=8G!4G nokaslr` to GRUB_CMDLINE_LINUX_DEFAULT
    #   this reserves 8G starting at 4G offset of DRAM as `/dev/pmem0`
sudo update-grub && sudo update-grub2
```

Reboot and verify that the correct kernel is booted with the desired parameters:

```bash
sudo reboot
uname -r            # should see 5.4.0-91-splitfs
cat /proc/cmdline   # check boot parameters
ls /dev             # should see /dev/pmem0
```

## Build SplitFS Library

Build SplitFS dynamic library:

```bash
cd splitfs
make clean && make
cd ..
```

Notice that setting `LEDGER_YCSB` environment variable is not set here. SplitFS source code uses macro flags (derived from environment variables) extensively to turn code pieces on/off... This is definitely a BAD DESIGN imo. I was only able to run the microbenchmark successfully without any `LEDGER_*` variables on.

## Set Up Ext4-DAX

Format `pmem0` into ext4 and mount in DAX mode:

```bash
sudo mkfs.ext4 -b 4096 /dev/pmem0
sudo mkdir /mnt/pmem_emul
sudo mount -o dax /dev/pmem0 /mnt/pmem_emul
sudo chown -R $USER /mnt/pmem_emul
```

## Run Microbenchmark

Build microbenchmark:

```bash
cd micro
make
cd ..
```

Run with raw ext4-DAX:

```bash
sudo sync && sudo bash -c 'echo 3 > /proc/sys/vm/drop_caches'
./micro/rw_expt write seq 4096
```

In `splitfs/nvp_lock.h` line 55 the number of per-core locks is hardcoded (CAN YOU BELIEVE IT):

```C
    #define NVP_NUM_LOCKS   32      // == 2 * num of CPU cores
```

, so processes running over SplitFS must be on CPU core <= 15 if you have a machine with more cores. Core pinning could be done through `taskset`.

Run with SplitFS:

```bash
rm -f /mnt/pmem_emul/append.log /mnt/pmem_emul/DR-* /mnt/pmem_emul/test.txt
export LD_LIBRARY_PATH=$(realpath .)/splitfs
export NVP_TREE_FILE=$(realpath .)/splitfs/bin/nvp_nvp.tree
sudo sync && sudo bash -c 'echo 3 > /proc/sys/vm/drop_caches'
taskset -c 0-7 bash -c 'LD_PRELOAD=$(realpath .)/splitfs/libnvp.so ./micro/rw_expt write seq 4096'
```

---

## Application: LevelDB

Get LevelDB and compile:

```bash
git clone https://github.com/google/leveldb.git
cd leveldb
git submodule update --init --recursive
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build . -j
```

Theoretically, LevelDB tests should run successfully through:

```bash
rm -f /mnt/pmem_emul/append.log /mnt/pmem_emul/DR-*
mkdir /mnt/pmem_emul/leveldbdir
export LD_LIBRARY_PATH=$(realpath .)/splitfs
export NVP_TREE_FILE=$(realpath .)/splitfs/bin/nvp_nvp.tree
taskset -c 0-7 bash -c 'LD_PRELOAD=/path/to/splitfs/libnvp.so TEST_TMPDIR=/mnt/pmem_emul/leveldbdir ./db_test'
```

However, on my side, SplitFS hangs in tests such as `SparseMerge`. I was not able to debug it because the source code looks like quite a mess.
