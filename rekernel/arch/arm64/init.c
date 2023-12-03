#include <stdint.h>

#include "sys.h"
#include "vm.h"

extern uint8_t ttb0_base;

static struct pagetable pt;

static void map_gb(uint64_t gb, int mair) {
    pt.entries[gb] = (struct pte){
        .valid = 1,
        .sh = 0b11,
        .af = 1,
        .index = mair,
        .addr = (gb << 30) >> 12,
    };
}

void arch_init() {
    // clear OS lock
    wr_sys(oslar_el1, 0);
    // enable simd/fp
    wr_sys(cpacr_el1, rd_sys(cpacr_el1) | (0b11 << 20));

    wr_sys(tcr_el1, 0xb5193519);
    wr_sys(mair_el1, 0xff);

    map_gb(0, 0);
    map_gb(1, 1);

    wr_sys(ttbr0_el1, (uintptr_t) &pt);
    wr_sys(sctlr_el1, rd_sys(sctlr_el1) | (1 << 2) | (1 << 12) | (1 << 0));

    dsb();
    isb();
}
