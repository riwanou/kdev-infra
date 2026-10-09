#!/bin/bash
#
# just build
# just kselftest
# just run "./tests/kselftest.sh off numa_replication"
# just run "./tests/kselftest.sh on mmap"
# just run "build/dev/kselftest/mm/numa_replication_mm 'file: migrate'"
# 

mkdir -p /tmp/ram && mount -t ramfs ramfs /tmp/ram
mkdir -p /tmp/ext4 && truncate -s 1G /tmp/ram/ext4.img && mkfs.ext4 -qF /tmp/ram/ext4.img && mount -o loop /tmp/ram/ext4.img /tmp/ext4 || exit 1
export REPL_TEST_DIR=/tmp/ext4

dd if=/dev/zero of=/tmp/ext4/swap bs=1M count=256 status=none && chmod 600 /tmp/ext4/swap && mkswap -q /tmp/ext4/swap && swapon /tmp/ext4/swap
trap 'swapoff /tmp/ext4/swap' EXIT

[ "$1" = on ] && echo 1 > /proc/self/numa_repl
shift

cd build/dev/kselftest

if [ $# = 0 ]; then ./run_kselftest.sh -c mm
else ./run_kselftest.sh $(for c in "$@"; do echo "-t mm:ksft_$c.sh"; done)
fi
