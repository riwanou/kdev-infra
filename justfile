KERNEL_REMOTE := "git@github.com:riwanou/linux.git"
KERNEL_BRANCH := "numa-repl"

# shallow clone of the kernel branch into linux/ (for test machines)
clone branch=KERNEL_BRANCH:
    git clone --depth 1 --branch {{branch}} {{KERNEL_REMOTE}} linux
    
