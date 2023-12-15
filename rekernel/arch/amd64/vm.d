module arch.amd64.vm;

import arch.amd64.sys;

import core.alloc;

import vm;
import sys;

enum {
    PTE_P = 1,    // present
    PTE_W = 2,    // writeable
    PTE_U = 4,    // user-accessible
    PTE_A = 32,   // accessed
    PTE_D = 64,   // dirty
    PTE_PS = 128, // large page size

    PAGEOFFBITS   = 12,
    PAGEINDEXBITS = 9,
}

private int pageindex(uintptr addr, int level) {
    return cast(int) (addr >> (PAGEOFFBITS + (3 - level) * PAGEINDEXBITS)) & 0x1FFU;
}

struct Pte {
    ulong data;

    uintptr pa() {
        return data & ~0xFFFUL;
    }

    bool leaf(uint level) {
        return level == Pagetable.LEVEL_4K || (data & PTE_PS) != 0;
    }

    void pa(uintptr pa) {
        // TODO: setting this multiple times is bad
        data = pa & ~0xFFFUL;
    }

    ubyte valid() {
        return data & PTE_P;
    }

    void valid(ubyte b) {
        if (b)
            data |= PTE_P;
        else
            data &= ~PTE_P;
    }

    void perm(Perm perm) {
        data &= ~(PTE_P | PTE_W | PTE_U);
        if (perm & Perm.READ)
            data |= PTE_P;
        if (perm & Perm.WRITE)
            data |= PTE_W;
        if (perm & Perm.USER)
            data |= PTE_U;
    }

    Perm perm() {
        Perm perm;
        if (data & PTE_P)
            perm |= Perm.READ;
        if (data & PTE_W)
            perm |= Perm.WRITE;
        if (data & PTE_U)
            perm |= Perm.USER;
        return perm;
    }
}

Pagetable* lookup_l4pagetable(Pagetable* pagetable, uintptr va, Perm perm, Pagetable* function() ptalloc) {
    Pagetable* pt = pagetable;
    for (int i = 0; i <= 2; i++) {
        Pte* pte = &pt.ptes[pageindex(va, i)];
        if (!pte.valid) {
            // Allocate a new pagetable if required.
            if (!ptalloc) {
                return null;
            }
            Pagetable* new_pt = ptalloc();
            if (!new_pt)
                return null;
            pte.pa = ka2pa(cast(uintptr) new_pt);
            pte.perm = perm;
        }
        pt = cast(Pagetable*) pa2ka(pte.pa());
    }
    return pt;
}

struct Pagetable {
    enum : uint {
        LEVEL_512G = 3,
        LEVEL_1G = 2,
        LEVEL_2M = 1,
        LEVEL_4K = 0,

        LEVEL_MAX = 3,
    }

    align (PAGESIZE) Pte[512] ptes;

    Pte* walk(uintptr va, ref uint endlevel) {
        Pagetable* pt = &this;
        Pte* pte;
        int i;
        for (i = LEVEL_MAX; i >= endlevel; i--) {
            uint lvl = 3 - i;
            pte = &pt.ptes[pageindex(va, lvl)];
            if (!pte.valid || pte.leaf(i)) {
                break;
            }
            pt = cast(Pagetable*) pa2ka(pte.pa());
        }
        endlevel = i;
        return pte;
    }

    bool map_region(uintptr va, uintptr pa, usize size, Perm perm) {
        return map_region(va, pa, size, perm, &knew!(Pagetable));
    }

    bool map_region(uintptr va, uintptr pa, usize size, Perm perm, Pagetable* function() ptalloc) {
        assert(size % PAGESIZE == 0);
        ssize last_index = -1;
        Pagetable* l4pagetable = null;
        for (; size != 0; va += PAGESIZE, pa += PAGESIZE, size -= PAGESIZE) {
            ssize cur_index = (va >> (PAGEOFFBITS + PAGEINDEXBITS));
            if (cur_index != last_index) {
                l4pagetable = lookup_l4pagetable(&this, va, perm, ptalloc);
                last_index = cur_index;
            }
            if ((perm & Perm.READ) && l4pagetable) {
                Pte* pte = &l4pagetable.ptes[pageindex(va, 3)];
                pte.pa = pa;
                pte.perm = perm;
            } else if (l4pagetable) {
                l4pagetable.ptes[pageindex(va, 3)].perm = perm;
            } else if (perm & Perm.READ) {
                return false;
            }
        }
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

void wrpt(Pagetable* pt) {
    wr_cr3(ka2pa(cast(uintptr) pt));
}

extern (C) __gshared {
    // Note these are stored at physical locations (in .lowdata).
    extern Pagetable init_pdp_upper;
    extern Pagetable init_pdp;
}

void kernel_map(Pagetable* pt) {
    pt.ptes[256].data = cast(uintptr) &init_pdp | 0b11;
    pt.ptes[511].data = cast(uintptr) &init_pdp_upper | 0b11;
}
