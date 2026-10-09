#!/bin/sh
# ann.sh: an ann-benchmarks run, replicated; REPL=0 PLACEMENT= TIME= WATCH=1 PROF=1
#   RUNNER=usearch|faiss|annoy  DATASET=gist|glove|sift
#   PRESSURE="n3:2G:10-20 n2:2G:10-20 cg:6G:25-35"  node or cgroup:size:from-to seconds
#
# just run "REPL=1 WATCH=0 PROF=1 TIME=4 ./tests/ann.sh"
# just MEM=16G run "TIME=10 WATCH=1 PROF=1 ./tests/ann.sh"
# 
# just MEM=16G run "TIME=30 WATCH=1 PROF=1 PRESSURE='cg:2G:10-20' PLACEMENT=dynamic ./tests/ann.sh"
# just MEM=16G run "TIME=40 WATCH=1 PRESSURE='n3:3G:10-20 n2:3G:10-20 cg:6G:25-35' ./tests/ann.sh"
#
R=/sys/kernel/mm/numa_replication
G=/sys/fs/cgroup/ann
t=$(dirname "$0")

case ${RUNNER:=usearch} in
usearch) suffix=.usearch ;;
faiss) suffix=.ivf ;;
annoy) suffix=.ann ;;
esac
case ${DATASET:=gist} in
glove) DATASET=glove-100-angular.hdf5 ;;
gist) DATASET=gist-960-euclidean.hdf5 ;;
sift) DATASET=sift-128-euclidean.hdf5 ;;
esac

echo $suffix > $R/files
[ -n "$PLACEMENT" ] && echo "$PLACEMENT" > $R/main_placement
# node reclaim skips nodes with little page cache, and replicas are anon
sysctl -qw vm.min_unmapped_ratio=0 vm.min_slab_ratio=0
echo +memory > /sys/fs/cgroup/cgroup.subtree_control && mkdir -p $G

pressure() {
	sleep $3
	echo "-- ${3}s: $1 $2"
	if [ $1 = cg ]; then echo $2 | dd of=$G/memory.high oflag=nonblock status=none; else memhog -r1000000 $2 membind ${1#n} > /dev/null & fi
	sleep $(($4 - $3))
	echo "-- ${4}s: $1 off"
	if [ $1 = cg ]; then echo max > $G/memory.high; else kill $!; fi
}

# only the run is replicated and in the cgroup, not the watchers
(
	cd /home/riwan/app-repl-numa-benchmarks || exit 1
	echo 0 > $G/cgroup.procs
	[ "${REPL:-1}" = 1 ] && echo 1 > /proc/self/numa_repl
	exec .venv/bin/python -u run_ann.py --$RUNNER --bench --datasets $DATASET \
		--running-time ${TIME:-60}
) &
p=$!
[ "$WATCH" = 1 ] && $t/watch.sh $p &
[ "$PROF" = 1 ] && $t/prof.sh $p &
for x in $PRESSURE; do pressure $(echo $x | tr :- ' ') & done
wait
