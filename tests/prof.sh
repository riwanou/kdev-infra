#!/bin/sh
# just run "REPL=0 WATCH=0 PROF=1 TIME=4 ./tests/ann.sh"
# just run "REPL=1 WATCH=0 PROF=1 TIME=4 ./tests/ann.sh"
d=/tmp/perf
perf stat -e cycles,instructions,cache-misses,dTLB-load-misses -p "$1" -o $d.stat 2>/dev/null &
perf record -q -e cpu-clock -p "$1" -o $d.data 2>/dev/null
wait
grep -E 'cycles|instructions|misses' $d.stat
perf report -i $d.data --stdio -q --dsos '[kernel.kallsyms]' --percentage absolute \
	--sort sym 2>/dev/null | awk '
	{ k += $1 } $3 ~ /^repl_/ { r += $1 } NR <= 10 { top = top $0 "\n" }
	END { printf "-- kernel %.2f%% of the time, repl_* %.2f%%\n%s", k, r, top }'
