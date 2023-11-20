#include <assert.h>
#include <string.h>

#include "kernel.h"
#include "x86-64.h"

// virtual_memory_map(pagetable, va, pa, sz, perm, allocator)
//    Map virtual address range `[va, va+sz)` in `pagetable`.
//    When `X >= 0 && X < sz`, the new pagetable will map virtual address
//    `va+X` to physical address `pa+X` with permissions `perm`.
//
//    Precondition: `va`, `pa`, and `sz` must be multiples of PAGESIZE
//    (4096).
//
//    Typically `perm` is a combination of `PTE_P` (the memory is Present),
//    `PTE_W` (the memory is Writable), and `PTE_U` (the memory may be
//    accessed by User applications). If `!(perm & PTE_P)`, `pa` is ignored.
//
//    Sometimes mapping memory will require allocating new page tables. The
//    `allocator` function should return a newly allocated page, or NULL
//    on allocation failure.
//
//    Returns 0 if the map succeeds, -1 if it fails (because a required
//    page table could not be allocated).

static x86_64_pagetable* lookup_l4pagetable(x86_64_pagetable* pagetable,
                 uintptr_t va, int perm, x86_64_pagetable* (*allocator)(void));

int virtual_memory_map(x86_64_pagetable* pagetable, uintptr_t va,
                       uintptr_t pa, size_t sz, int perm,
                       x86_64_pagetable* (*allocator)(void)) {
    assert(va % PAGESIZE == 0); // virtual address is page-aligned
    assert(sz % PAGESIZE == 0); // size is a multiple of PAGESIZE
    assert(va + sz >= va || va + sz == 0); // va range does not wrap
    if (perm & PTE_P) {
        assert(pa % PAGESIZE == 0); // physical addr is page-aligned
        assert(pa + sz >= pa);      // physical address range does not wrap
        assert(pa + sz <= MEMSIZE_PHYSICAL); // physical addresses exist
    }
    assert(perm >= 0 && perm < 0x1000); // `perm` makes sense
    assert((uintptr_t) pagetable % PAGESIZE == 0); // `pagetable` page-aligned

    int last_index123 = -1;
    x86_64_pagetable* l4pagetable = NULL;
    for (; sz != 0; va += PAGESIZE, pa += PAGESIZE, sz -= PAGESIZE) {
        int cur_index123 = (va >> (PAGEOFFBITS + PAGEINDEXBITS));
        if (cur_index123 != last_index123) {
            l4pagetable = lookup_l4pagetable(pagetable, va, perm, allocator);
            last_index123 = cur_index123;
        }
        if ((perm & PTE_P) && l4pagetable) {
            l4pagetable->entry[L4PAGEINDEX(va)] = pa | perm;
        } else if (l4pagetable) {
            l4pagetable->entry[L4PAGEINDEX(va)] = perm;
        } else if (perm & PTE_P) {
            return -1;
        }
    }
    return 0;
}

static x86_64_pagetable* lookup_l4pagetable(x86_64_pagetable* pagetable,
                 uintptr_t va, int perm, x86_64_pagetable* (*allocator)(void)) {
    x86_64_pagetable* pt = pagetable;
    for (int i = 0; i <= 2; ++i) {
        x86_64_pageentry_t pe = pt->entry[PAGEINDEX(va, i)];
        if (!(pe & PTE_P)) {
            // allocate a new page table page if required
            if (!(perm & PTE_P) || !allocator) {
                return NULL;
            }
            x86_64_pagetable* new_pt = allocator();
            if (!new_pt) {
                return NULL;
            }
            assert((uintptr_t) new_pt % PAGESIZE == 0);
            pt->entry[PAGEINDEX(va, i)] = pe =
                PTE_ADDR(new_pt) | PTE_P | PTE_W | PTE_U;
            memset(new_pt, 0, PAGESIZE);
        }

        // sanity-check page entry
        assert(PTE_ADDR(pe) < MEMSIZE_PHYSICAL); // at sensible address
        if (perm & PTE_W) {       // if requester wants PTE_W,
            assert(pe & PTE_W);   //   entry must allow PTE_W
        }
        if (perm & PTE_U) {       // if requester wants PTE_U,
            assert(pe & PTE_U);   //   entry must allow PTE_U
        }

        pt = (x86_64_pagetable*) PTE_ADDR(pe);
    }
    return pt;
}


// virtual_memory_lookup(pagetable, va)
//    Returns information about the mapping of the virtual address `va` in
//    `pagetable`. The information is returned as a `vamapping` object.

vamapping virtual_memory_lookup(x86_64_pagetable* pagetable, uintptr_t va) {
    x86_64_pagetable* pt = pagetable;
    x86_64_pageentry_t pe = PTE_W | PTE_U | PTE_P;
    for (int i = 0; i <= 3 && (pe & PTE_P); ++i) {
        pe = pt->entry[PAGEINDEX(va, i)] & ~(pe & (PTE_W | PTE_U));
        pt = (x86_64_pagetable*) PTE_ADDR(pe);
    }
    vamapping vam = { -1, (uintptr_t) -1, 0 };
    if (pe & PTE_P) {
        vam.pn = PAGENUMBER(pe);
        vam.pa = PTE_ADDR(pe) + PAGEOFFSET(va);
        vam.perm = PTE_FLAGS(pe);
    }
    return vam;
}
