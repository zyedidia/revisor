#include <stdint.h>

#include "sys.h"
#include "vm.h"

extern uint64_t memory_size;

void arch_init() {
    // clear OS lock
    wr_sys(oslar_el1, 0);
    // enable simd/fp
    wr_sys(cpacr_el1, rd_sys(cpacr_el1) | (0b11 << 20));
}
