#!/bin/bash
#
# just build
# just kselftest
# just run "./tests/repl_events.sh 'anon: r* w1 r* wL wL w0 r*'"
# just run "REPL_TRACE=0 REPL_PAGES=32 ./tests/repl_events.sh 'file: interleave'"
#
exec 2>&1
trace=${REPL_TRACE:-1}
[ "$trace" = 1 ] && trace-cmd start -e numa_replication
REPL_STAT=1 REPL_SZ=$((${REPL_PAGES:-1} * 4096)) perf stat -e 'numa_replication:*' build/dev/kselftest/mm/numa_replication_fault "$1"
[ "$trace" = 1 ] && trace-cmd show
