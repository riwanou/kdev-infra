#!/bin/bash
#
# just build
# just kselftest
# just run "./tests/kselftest.sh off numa_replication"
# just run "./tests/kselftest.sh on mmap"
# 
[ "$1" = on ] && echo 1 > /proc/self/numa_repl
shift
cd build/dev/kselftest
if [ $# = 0 ]; then ./run_kselftest.sh -c mm
else ./run_kselftest.sh $(for c in "$@"; do echo "-t mm:ksft_$c.sh"; done)
fi
