#include <stdint.h>

#include "arch/arm64/sys.h"
#include "arch/arm64/vm.h"

extern uint64_t memory_size;
extern void ktrap_entry();

void arch_init() {
    // clear OS lock
    wr_sys(oslar_el1, 0);
    // enable simd/fp
    wr_sys(cpacr_el1, rd_sys(cpacr_el1) | (0b11 << 20));

    wr_sys(vbar_el1, ktrap_entry);
}
