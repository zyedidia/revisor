module vm;

import arch.vm;
import arch.sys;

import core.option;

enum Perm {
    NONE = 0,
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
        return VmMap(false, 0, Perm.NONE, 0);
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

enum {
    MAP_SHARED    = 0x001,
    MAP_PRIVATE   = 0x002,
    MAP_FIXED     = 0x010,
    MAP_FILE      = 0x000,
    MAP_ANONYMOUS = 0x020,
}

struct VmArea {
    int prot;
    int flags;
}

struct VaMapping {
    Pte* pte;
    uintptr va_;
    usize size;

    uintptr va() { return va_; }
    uintptr pa() { return pte.pa; }
    uintptr ka() { return pa2ka(pte.pa); }
    Perm perm()  { return pte.perm; }
    bool read()  { return (pte.perm & Perm.READ) != 0; }
    bool write() { return (pte.perm & Perm.WRITE) != 0; }
    bool exec()  { return (pte.perm & Perm.EXEC) != 0; }
    bool user()  { return (pte.perm & Perm.USER) != 0; }
    bool cow()   { return (pte.perm & Perm.COW) != 0; }

    ubyte[] pg() {
        return (cast(ubyte*) pa2ka(pte.pa))[0 .. PAGESIZE];
    }

    ubyte* pg_raw() {
        return cast(ubyte*) pa2ka(pte.pa);
    }
}

struct PtIter {
    usize idx;
    uintptr va;
    Pte* pte;
    Pagetable* pt;

    static PtIter get(Pagetable* pt) {
        return PtIter(0, 0, null, pt);
    }

    bool advance() {
        if (va > USER_END) {
            return false;
        }

        uint lvl = Pagetable.LEVEL_4K;
        Pte* entry = pt.walk(va, lvl);
        if (entry) {
            if (lvl != Pagetable.LEVEL_4K || !entry.valid()) {
                pte = null;
            } else {
                pte = entry;
            }
            va += Pagetable.lvl2size(lvl);
        } else {
            pte = null;
            va += Pagetable.lvl2size(Pagetable.LEVEL_4K);
        }
        return true;
    }

    Option!(VaMapping) next() {
        uintptr va = this.va;
        if (!advance()) {
            return Option!(VaMapping).none;
        }

        while (!pte) {
            va = this.va;
            if (!advance()) {
                return Option!(VaMapping).none;
            }
        }
        return Option!(VaMapping)(VaMapping(pte, va, Pagetable.lvl2size(Pagetable.LEVEL_4K)));
    }

    int opApply(scope int delegate(ref VaMapping) dg) {
        for (auto map = next(); map.has(); map = next()) {
            VaMapping m = map.get();
            int r = dg(m);
            if (r) return r;
        }
        return 0;
    }
}
