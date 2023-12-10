module vm;

import arch.vm;
import arch.sys;

enum Perm {
    READ  = 1 << 0,
    WRITE = 1 << 1,
    EXEC  = 1 << 2,
    USER  = 1 << 3,
    COW   = 1 << 4,
}

struct VmMap {
    bool valid;
    uintptr pa;
    Perm perm;
    usize size;

    uintptr ka() {
        return pa2ka(pa);
    }
}

VmMap vm_lookup(Pagetable* pt, uintptr va) {
    uint level;
    Pte* pte = pt.walk(va, level);
    if (!pte || !pte.valid) {
        return VmMap(false, 0, Perm(), 0);
    }
    usize ptesz = Pagetable.lvl2size(level);
    uintptr va_align = va & ~(ptesz - 1);

    return VmMap(
        pte.valid == 1,
        pte.pa + (va - va_align),
        pte.perm,
        ptesz - (va - va_align),
    );
}

enum {
    PROT_NONE  = 0,
    PROT_READ  = 1,
    PROT_WRITE = 2,
    PROT_EXEC  = 4,
}

Perm prot2perm(int prot) {
    Perm perm;
    if ((prot & PROT_READ) != 0)
        perm |= Perm.READ;
    if ((prot & PROT_WRITE) != 0)
        perm |= Perm.WRITE;
    if ((prot & PROT_EXEC) != 0)
        perm |= Perm.EXEC;
    return perm;
}

struct VmArea {
    int prot;
    int flags;
}
