KERNEL_REMOTE := "git@github.com:riwanou/linux.git"
KERNEL_BRANCH := "numa-repl"

K := justfile_directory() / "linux"
B := justfile_directory() / "build"

MEM := "8G"
NODE_MEM := "2G"

[group('run')]
run cmd name="dev":
    vng -r {{B}}/{{name}} --user root -m {{MEM}} \
        --numa {{NODE_MEM}},cpus=0-5 --numa {{NODE_MEM}},cpus=6-11 \
        --numa {{NODE_MEM}},cpus=12-17 --numa {{NODE_MEM}},cpus=18-23 \
        --append "nokaslr norandmaps panic_on_warn=1 i8042.noaux i8042.nokbd libata.force=disable" \
        --exec "{{cmd}}"

[group('build')]
build name="dev":
    make -C {{K}} O={{B}}/{{name}} LLVM=1 -j$(nproc) bzImage modules

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
