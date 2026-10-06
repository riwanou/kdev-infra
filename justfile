KERNEL_REMOTE := "git@github.com:riwanou/linux.git"
KERNEL_BRANCH := "numa-repl"

K := justfile_directory() / "linux"
B := justfile_directory() / "build"

MEM := "8G"
NODE_MEM := "2G"

set positional-arguments

[group('run')]
run cmd="" name="dev" gdb="":
    vng -r {{B}}/{{name}} --user root -m {{MEM}} --verbose \
        --numa {{NODE_MEM}},cpus=0-5 --numa {{NODE_MEM}},cpus=6-11 \
        --numa {{NODE_MEM}},cpus=12-17 --numa {{NODE_MEM}},cpus=18-23 \
        --append "no5lvl nokaslr norandmaps panic_on_warn=1 i8042.noaux i8042.nokbd libata.force=disable loglevel=5" \
        {{ if gdb != "" { "--qemu-opts='-s -S'" } else { "" } }} \
        {{ if cmd != "" { "--exec " + quote(cmd) } else { "" } }}

[group('check')]
ci:
    @echo "{{BOLD}}== checkpatch{{NORMAL}}"
    cd {{K}} && { git diff numa-repl; git ls-files -z -o --exclude-standard | xargs -r0 -n1 git diff --no-index /dev/null; } | scripts/checkpatch.pl --no-tree --ignore FILE_PATH_CHANGES -
    # @echo "{{BOLD}}== vma userspace tests{{NORMAL}}"
    make -C {{K}}/tools/testing/vma && {{K}}/tools/testing/vma/vma
    # @echo "{{BOLD}}== build without replication{{NORMAL}}"
    just build norepl
    # @echo "{{BOLD}}== build and selftests{{NORMAL}}"
    just build
    just kselftest
    just run "./tests/kselftest.sh off numa_replication"
    # @echo "{{BOLD}}== stress{{NORMAL}}"
    just run "bash -c 'echo 1 > /proc/self/numa_repl; stress-ng --fork 0 --vm 0 --vm-bytes 32M --verify --switch 0 -t 5s'"
    # @echo "{{GREEN}}{{BOLD}}ci: all checks passed{{NORMAL}}"

[group('build')]
build name="dev":
    make -C {{K}} O={{B}}/{{name}} LLVM=1 -j$(nproc) bzImage modules scripts_gdb

[group('build')]
kselftest name="dev":
    make -C {{K}} O={{B}}/{{name}} LLVM=1 headers
    make -C {{K}}/tools/testing/selftests TARGETS=mm O={{B}}/{{name}}/kselftest-build \
        KHDR_INCLUDES="-isystem {{B}}/{{name}}/usr/include" \
        INSTALL_PATH={{B}}/{{name}}/kselftest -j$(nproc) install

[group('debug')]
gdb name="dev":
    gdb -x gdbinit {{B}}/{{name}}/vmlinux

[group('debug')]
rip line name="dev":
    #!/usr/bin/env bash
    set -e
    vmlinux={{B}}/{{name}}/vmlinux
    read sym off < <(sed -E 's/^(.*[: ])?([A-Za-z0-9_.]+)\+(0x[0-9a-f]+).*/\2 \3/' <<< "$1")
    base=$(llvm-nm "$vmlinux" | awk -v s="$sym" '$3==s {print $1; exit}')
    llvm-addr2line -i -f -p -e "$vmlinux" $(printf '0x%x' $((0x$base + off)))

[group('debug')]
oops name="dev":
    LLVM=1 {{K}}/scripts/decode_stacktrace.sh {{B}}/{{name}}/vmlinux

[group('build')]
compdb name="dev":
    make -C {{K}} O={{B}}/{{name}} LLVM=1 compile_commands.json

[group('config')]
config name="dev":
    mkdir -p {{B}}/{{name}}
    cat configs/base.config configs/{{name}}.config > {{B}}/{{name}}/.config
    make -C {{K}} O={{B}}/{{name}} LLVM=1 olddefconfig
    cp {{B}}/{{name}}/.config configs/{{name}}.resolved

[group('config')]
menuconfig name="dev":
    make -C {{K}} O={{B}}/{{name}} LLVM=1 menuconfig

[group('config')]
base:
    cd {{K}} && vng -k
    mv {{K}}/.config configs/base.config
    make -C {{K}} mrproper
    
[group('setup')]
clone branch=KERNEL_BRANCH:
    git clone --depth 1 --branch {{branch}} {{KERNEL_REMOTE}} linux
