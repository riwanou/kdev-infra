import gdb

MMF_NUMA_REPL = 32


def val(expr):
    return gdb.parse_and_eval(expr)


def pa(va):
    return int(va) - int(val("page_offset_base"))


def nid(pa_):
    pfn = pa_ >> 12
    for n in range(int(val("nr_node_ids"))):
        pd = val(f"node_data[{n}]")
        start = int(pd["node_start_pfn"])
        if start <= pfn < start + int(pd["node_spanned_pages"]):
            return n
    return -1


def current_mm():
    return val("$lx_current()->active_mm")


class PaFn(gdb.Function):
    """$rx_pa(va): physical address of a kernel direct-map address."""
    def __init__(self):
        super().__init__("rx_pa")

    def invoke(self, va):
        return pa(va)


class NidFn(gdb.Function):
    """$rx_nid(va): node of the page behind a kernel direct-map address."""
    def __init__(self):
        super().__init__("rx_nid")

    def invoke(self, va):
        return nid(pa(va))


class Pt(gdb.Command):
    """rx-pt ADDR [PGD]: walk the 4-level page table for ADDR.
PGD defaults to the active mm's pgd, e.g. pt 0x7ffff7dd0000 mm->repl->pgds[2]"""
    def __init__(self):
        super().__init__("rx-pt", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        argv = gdb.string_to_argv(arg)
        addr = int(val(argv[0]))
        table = pa(val(argv[1]) if len(argv) > 1 else current_mm()["pgd"])
        mem = gdb.selected_inferior()
        for name, shift in (("pgd", 39), ("pud", 30), ("pmd", 21), ("pte", 12)):
            idx = (addr >> shift) & 511
            raw = mem.read_memory(table + int(val("page_offset_base")) + idx * 8, 8)
            e = int.from_bytes(raw.tobytes(), "little")
            print(f"{name}[{idx:3}] {e:#018x}  table on node {nid(table)}"
                  f"{'  P' if e & 1 else '  none'}{' RW' if e & 2 else ''}"
                  f"{' U' if e & 4 else ''}{' HUGE' if e & 0x80 and name in ('pud', 'pmd') else ''}"
                  f"{' NX' if e >> 63 else ''}")
            if not e & 1 or (e & 0x80 and name in ("pud", "pmd")):
                return
            table = e & 0x000ffffffffff000
        print(f"page pa {table:#x} on node {nid(table)}")


class ReplMm(gdb.Command):
    """rx-mm [MM]: an mm's PGDs, their nodes, and which one CR3 holds."""
    def __init__(self):
        super().__init__("rx-mm", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        mm = val(arg) if arg else current_mm()
        cr3 = int(val("$cr3")) & ~0xfff
        opted = (int(mm["flags"]["__mm_flags"][0]) >> MMF_NUMA_REPL) & 1
        print(f"mm {int(mm):#x}  opted-in {opted}  main pgd {int(mm['pgd']):#x}")
        if int(mm["repl"]) == 0:
            return
        pgds = mm["repl"]["pgds"]
        for i in range(pgds.type.range()[1] + 1):
            p = int(pgds[i])
            if p:
                print(f"  [{i}] {p:#x}  on node {nid(pa(p))}"
                      f"{'  <- cr3' if pa(p) == cr3 else ''}")

def read_pgd(p):
    raw = gdb.selected_inferior().read_memory(p, 4096).tobytes()
    return [int.from_bytes(raw[i * 8:i * 8 + 8], "little") for i in range(512)]


def mm_pgds(mm):
    """main pgd first, then the replicas that are not the main one"""
    pgds = [int(mm["pgd"])]
    if int(mm["repl"]):
        arr = mm["repl"]["pgds"]
        pgds += [int(arr[i]) for i in range(arr.type.range()[1] + 1)
                 if int(arr[i]) not in (0, pgds[0])]
    return pgds


def print_grid(pgds):
    tabs = [read_pgd(p) for p in pgds]
    print("pgds: " + "  ".join(f"{p:#x} (node {nid(pa(p))})" for p in pgds))
    for row in range(8):
        if row in (0, 4):
            print(f"  {'user' if row == 0 else 'kernel'} ".ljust(78, "-"))
        cells = ""
        for i in range(row * 64, row * 64 + 64):
            e = tabs[0][i]
            if any(t[i] != e for t in tabs):
                c = "*"
            elif not e:
                c = "."
            else:
                n = nid(e & 0x000ffffffffff000)
                c = format(n, "x") if n >= 0 else "?"
            cells += c + (" " if i % 8 == 7 else "")
        print(f"  {row * 64:3}  {cells}")


class RxMap(gdb.Command):
    """rx-map [PGD ...]: the 512 entries of PGDs as one grid, one char each.
digit = node of the table the entry points to, '.' = empty,
'*' = the PGDs disagree on that entry.
Default: main pgd and replicas of the active mm."""
    def __init__(self):
        super().__init__("rx-map", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        argv = gdb.string_to_argv(arg)
        print_grid([int(val(a)) for a in argv] if argv else mm_pgds(current_mm()))


class RxMaps(gdb.Command):
    """rx-maps [MM]: one grid per pgd of MM (default: active mm),
each compared with the main pgd: '*' = differs from main."""
    def __init__(self):
        super().__init__("rx-maps", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        pgds = mm_pgds(val(arg) if arg else current_mm())
        for p in pgds:
            print_grid([p] if p == pgds[0] else [pgds[0], p])


PaFn()
NidFn()
Pt()
ReplMm()
RxMap()
RxMaps()
