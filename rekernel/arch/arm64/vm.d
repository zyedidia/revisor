module arch.arm64.vm;

import bits = core.bits;
import core.alloc;

import arch.arm64.sys;

import vm;
import sys;

struct Pte {
    ulong data;

    mixin(bits.field!(data,
        "valid", 1,
        "table", 1, // if this entry is a table entry or leaf entry
        "index", 3, // mair index
        "ns", 1, // non-secure
        "ap", 2, // access permission
        "sh", 2, // shareable
        "af", 1, // access fault
        "ng", 1, // not global
        "addr", 36,
        "_r2", 2,
        "gp", 1,  // guarded page
        "dbm", 1, // dirty bit modifier
        "contiguous", 1,
        "pxn", 1, // privileged execute never
        "uxn", 1, // unprivileged execute never
        "cow", 1, // copy-on-write (software use)
        "sw", 3,  // reserved for software use
        "_r3", 5,
    ));

    uintptr pa() {
        return addr << 12;
    }

    void pa(uintptr pa) {
        addr = pa >> 12;
    }

    bool leaf(uint level) {
        if (level == 0) {
            return true;
        }
        return !this.table;
    }

    void perm(Perm perm) {
        valid = (perm & Perm.READ) != 0;
        cow = (perm & Perm.COW) != 0;
        pxn = (perm & Perm.EXEC) == 0;
        uxn = (perm & Perm.EXEC) == 0 || (perm & Perm.USER) == 0;
        ubyte ap = 0;
        if ((perm & Perm.USER) != 0)
            ap |= 0b01; // user-accessible
        if ((perm & Perm.WRITE) == 0)
            ap |= 0b10; // read-only
        this.ap = ap;
    }

    Perm perm() {
        Perm p;
        if (valid)
            p |= Perm.READ;
        if (!uxn || !pxn)
            p |= Perm.EXEC;
        // user-accessible if user could execute or read/write
        if (!uxn || (ap & 0b01) != 0)
            p |= Perm.USER;
        if ((ap & 0b10) == 0)
            p |= Perm.WRITE;
        if (cow)
            p |= Perm.COW;
        return p;
    }
}

private uintptr vpn(uint level, uintptr va) {
    return (va >> 12+9*level) & bits.mask!uintptr(9);
}

struct Pagetable {
    enum : uint {
        LEVEL_512G = 3,
        LEVEL_1G = 2,
        LEVEL_2M = 1,
        LEVEL_4K = 0,

        LEVEL_MAX = 3,
    }

    align(PAGESIZE) Pte[512] ptes;

    Pte* walk(uintptr va, ref uint endlevel, Pagetable* function() ptalloc) {
        Pagetable* pt = &this;

        for (int level = LEVEL_MAX; level > endlevel; level--) {
            Pte* pte = &pt.ptes[vpn(level, va)];
            if (pte.valid && pte.leaf(level)) {
                endlevel = level;
                return pte;
            } else if (pte.valid) {
                pt = cast(Pagetable*) pa2ka(pte.pa);
            } else {
                if (!ptalloc) {
                    endlevel = level;
                    return null;
                } else {
                    pt = ptalloc();
                    if (!pt) {
                        endlevel = level;
                        return null;
                    }
                    pte.pa = ka2pa(cast(uintptr) pt);
                    pte.valid = 1;
                    pte.table = 1;
                }
            }
        }
        return &pt.ptes[vpn(endlevel, va)];
    }

    Pte* walk(uintptr va, ref uint endlevel) {
        return walk(va, endlevel, null);
    }

    void free(uint level = LEVEL_MAX) {
        for (usize i = 0; i < ptes.length; i++) {
            Pte* pte = &ptes[i];
            if (pte.valid && !pte.leaf(level)) {
                Pagetable* child = cast(Pagetable*) pa2ka(pte.pa);
                assert(level > 0);
                child.free(level - 1);
                kfree(child);
            }
            pte.data = 0;
        }
    }

    bool map_region(uintptr va, uintptr pa, usize size, Perm perm) {
        assert(size % PAGESIZE == 0);
        for (usize i = 0; i < size; i += PAGESIZE) {
            if (!map(va + i, pa + i, LEVEL_4K, perm))
                return false;
        }
        return true;
    }

    bool map(uintptr va, uintptr pa, uint level, Perm perm) {
        return map(va, pa, level, perm, &knew!(Pagetable));
    }

    bool map(uintptr va, uintptr pa, uint level, Perm perm, Pagetable* function() ptalloc) {
        Pte* pte = walk(va, level, ptalloc);
        if (!pte) {
            return false;
        }
        pte.pa = pa;
        pte.valid = 1;
        pte.perm = perm;
        // last level PTEs leaf need the 'table' bit enabled (confusingly)
        pte.table = level == 0;
        pte.sh = 0b11;
        pte.af = 1;
        pte.index = 0;
        return true;
    }

    static usize lvl2size(uint level) {
        switch (level) {
        case LEVEL_4K:
            return kb(4);
        case LEVEL_2M:
            return mb(2);
        case LEVEL_1G:
            return gb(1);
        case LEVEL_512G:
            return gb(512);
        default:
            assert(0, "unreachable");
        }
    }
}

Pagetable* rdpt() {
    return cast(Pagetable*) pa2ka((SysReg.ttbr0_el1) & 0xfffffffffffe);
}

void wrpt(Pagetable* pt) {
    SysReg.ttbr0_el1 = ka2pa(cast(uintptr) pt);
    vm_fence();
}
