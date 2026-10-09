#!/bin/sh
perf stat -a -I 1000 -x, -e 'numa_replication:*' 2>&1 | awk -F, '
	function line(when, what) { printf "%7s%s\n", when "s", what; fflush() }
	function out() {
		if (ev == "") { if (!q) q = t; e = t; return }
		if (q) line(q == e ? q : q "-" e); q = 0
		line(t, ev)
	}
	{ s = sprintf("%.0f", $1) }
	s != t  { if (t != "") out(); t = s; ev = "" }
	$2 > 0  { sub("numa_replication:repl_", "", $4); ev = ev " " $4 "=" $2 }
	END     { if (t != "") out() }' &
prev=
while kill -0 "$1" 2>/dev/null; do
	cur=$(cat /proc/"$1"/numa_repl_stat 2>/dev/null)
	[ "$cur" != "$prev" ] && echo "$cur" && prev=$cur
	sleep 1
done
sleep 1
pkill -INT -f 'perf stat -a -I 1000'
wait
