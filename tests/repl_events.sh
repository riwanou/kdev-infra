#!/bin/bash
#
# just build
# just kselftest
# 
# just run "./tests/repl_events.sh 'anon: r* w1 r* wL wL w0 r*'"
# 
# just run "REPL_STAT=0 REPL_TRACE=0 ./tests/repl_events.sh"
# just run "REPL_TRACE=0 REPL_PAGES=32 ./tests/repl_events.sh 'file: interleave'"
# # just run "REPL_PAGES=1 REPL_TRACE=1 REPL_STAT=1 ./tests/repl_events.sh 'file: r0 mL wL m0 r* w1 r*'"
# just run "REPL_PAGES=512 REPL_TRACE=0 REPL_STAT=1 REPL_BIN=numa_replication_mm ./tests/repl_events.sh 'file: writeback: r0 mL wL | wL'"
# 
# just run "REPL_PAGES=1 REPL_TRACE=1 REPL_GRAPH=repl_un* REPL_NOGRAPH='*pmd* *pte*' REPL_STAT=1 ./tests/repl_events.sh 'file: w0 r* w1 x1 r*'"
#

mkdir -p /tmp/ram && mount -t ramfs ramfs /tmp/ram
mkdir -p /tmp/ext4 && truncate -s 1G /tmp/ram/ext4.img && mkfs.ext4 -qF /tmp/ram/ext4.img && mount -o loop /tmp/ram/ext4.img /tmp/ext4 || exit 1
export REPL_TEST_DIR=/tmp/ext4

dd if=/dev/zero of=/tmp/ext4/swap bs=1M count=256 status=none && chmod 600 /tmp/ext4/swap && mkswap -q /tmp/ext4/swap && swapon /tmp/ext4/swap
trap 'swapoff /tmp/ext4/swap' EXIT

exec 2>&1

trace=${REPL_TRACE:-1}
bin=${REPL_BIN:-numa_replication_fault}

graph=
for f in $REPL_GRAPH; do
	graph="$graph -g $f"
done
for f in $REPL_NOGRAPH; do
	graph="$graph -n $f"
done
[ -n "$REPL_GRAPH" ] && graph="-p function_graph$graph -l repl_* -O nofuncgraph-duration"
[ "$trace" = 1 ] && trace-cmd start -e numa_replication $graph

REPL_STAT=${REPL_STAT:-1} REPL_SZ=$((${REPL_PAGES:-1} * 4096)) perf stat -a -e 'numa_replication:*' build/dev/kselftest/mm/$bin "$@"

[ "$trace" = 0 ] || trace-cmd show
