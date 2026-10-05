#!/bin/bash
# usage: tests/kselftest.sh on|off [category ...]   e.g. tests/kselftest.sh on mremap cow
[ "$1" = on ] && echo 1 > /proc/self/numa_repl
shift
cd build/dev/kselftest
if [ $# = 0 ]; then ./run_kselftest.sh -c mm
else ./run_kselftest.sh $(for c in "$@"; do echo "-t mm:ksft_$c.sh"; done)
fi
