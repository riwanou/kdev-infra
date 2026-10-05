set confirm off
set pagination off
set print pretty on
set print frame-arguments all
set breakpoint pending on
set disassemble-next-line auto
set history save on
set history filename ~/.gdb_history
set history size 10000
set history remove-duplicates unlimited

target remote :1234

# `just run <cmd> dev 1` halts qemu at a point where kernel is not mapped yet
thbreak start_kernel
continue

define rx-reload
  source gdb/repl.py
end

rx-reload
