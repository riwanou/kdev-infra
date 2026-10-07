#!/bin/bash
#
# just build
# just kselftest
# just run "REPL_STAT=0 REPL_TRACE=0 ./tests/repl_events.sh"
# just run "./tests/repl_events.sh 'anon: r* w1 r* wL wL w0 r*'"
# just run "REPL_TRACE=0 REPL_PAGES=32 ./tests/repl_events.sh 'file: interleave'"
# just run "REPL_PAGES=1 REPL_TRACE=1 REPL_STAT=1 ./tests/repl_events.sh 'file: r0 mL wL m0 r* w1 r*'"
# just run "REPL_PAGES=512 REPL_TRACE=0 REPL_STAT=1 REPL_BIN=numa_replication_mm ./tests/repl_events.sh 'file: writeback: r0 mL wL | wL'"
#

mkdir -p /tmp/ext4 && truncate -s 1G /tmp/ext4.img && mkfs.ext4 -qF /tmp/ext4.img && mount -o loop /tmp/ext4.img /tmp/ext4 || exit 1
export REPL_TEST_DIR=/tmp/ext4

exec 2>&1

trace=${REPL_TRACE:-1}
bin=${REPL_BIN:-numa_replication_fault}

[ "$trace" = 1 ] && trace-cmd start -e numa_replication
REPL_STAT=${REPL_STAT:-1} REPL_SZ=$((${REPL_PAGES:-1} * 4096)) perf stat -e 'numa_replication:*' build/dev/kselftest/mm/$bin "$@"
[ "$trace" = 0 ] || trace-cmd show
