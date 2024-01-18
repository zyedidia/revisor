module trap;

import arch.sys;
import arch.vm;

import core.lib;
import core.interval;
import core.alloc;
import core.math;

import sys;
import syscall;
import proc;
import vm;
import timer;

noreturn unhandled(Proc* p) {
    printf("%d: killed (unhandled)\n", p.pid);
    exit(1);
}

enum Action {
    NONE,
    YIELD,
    EXIT,
}

enum Fault {
    READ,
    WRITE,
}

private bool mmap_fault(Proc* p, uintptr ptr, VmArea vma) {
    uintptr start = truncpg(ptr);

    uint lvl = Pagetable.LEVEL_4K;
    Pte* pte = p.pt.walk(start, lvl);
    if (pte && pte.valid)
        return false; // already mapped

    void* pg = kallocpage();
    if (!pg)
        return false;
    // TODO: prot
    if (!p.pt.map_region(start, ka2pa(pg), PAGESIZE, prot2perm(vma.prot) | Perm.USER)) {
        kfree(pg);
        return false;
    }
    return true;
}

void pagefault(Proc* p, uintptr ptr, Fault type) {
    Interval!(VmArea) vma;
    if (p.vmas.overlaps(ptr, 1, vma)) {
        if (mmap_fault(p, ptr, vma.val)) {
            return; // ok
        }
    }

    printf("%d: pagefault on address 0x%lx (pc=%lx, sp=%lx)\n", p.pid, ptr, p.trapframe.epc, p.trapframe.user_sp);

    sys_exit(p, 1);
}

enum Irq {
    TIMER,
}

Action irq(Irq type) {
    return Action.NONE;
}

Action signal(Proc* p, ulong sig) {
    eprintf("received signal: %lu\n", sig);
    return Action.EXIT;
}
