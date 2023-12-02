#include <stdint.h>

static void wr_oslar_el1(uintptr_t val) {
    asm volatile ("msr oslar_el1, %0" :: "r"(val));
}

static uintptr_t rd_cpacr_el1() {
    uintptr_t val;
    asm volatile ("mrs %0, cpacr_el1" : "=r"(val));
    return val;
}

static void wr_cpacr_el1(uintptr_t val) {
    asm volatile ("msr cpacr_el1, %0" :: "r"(val));
}

static void isb() {
    asm volatile ("isb");
}

void arch_init() {
    // clear OS lock
    wr_oslar_el1(0);
    // enable simd/fp
    wr_cpacr_el1(rd_cpacr_el1() | (0b11 << 20));

    isb();
}
