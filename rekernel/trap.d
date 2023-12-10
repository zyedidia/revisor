module trap;

import arch.sys;

import core.lib;
import core.interval;
import core.alloc;
import core.math;

import sys;
import syscall;
import proc;
import vm;

noreturn unhandled(Proc* p) {
    printf("%d: killed (unhandled)\n", p.pid);
    exit(1);
}

enum Fault {
    READ,
    WRITE,
}

private bool mmap_fault(Proc* p, uintptr ptr, VmArea vma) {
    uintptr start = truncpg(ptr);
    void* pg = kallocpage();
    if (!pg)
        return false;
    // TODO: prot
    printf("map %lx -> %lx\n", start, ka2pa(pg));
    if (!p.pt.map_region(start, ka2pa(pg), PAGESIZE, Perm.READ | Perm.WRITE | Perm.EXEC | Perm.USER)) {
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

    sys_exit(p, 1);
}
