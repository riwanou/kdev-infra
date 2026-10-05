#!/bin/bash

trace-cmd start -p function \
  -l repl_pgds_alloc -l repl_pgds_free \
  -l repl_p4ds_populate -l repl_p4ds_clear
(echo 1 > /proc/self/numa_repl; grep repl /proc/self/maps; /bin/true; /bin/true)
trace-cmd show



echo 1 > /proc/self/numa_repl
stress-ng --fork 0 --vm 0 --vm-bytes 32M --verify --switch 0 -t 1s --metrics-brief
