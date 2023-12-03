#pragma once

#define wr_sys(reg, val) _wr_sys(reg, val)
#define rd_sys(reg) _rd_sys(reg)

#define _rd_sys(reg) ({ unsigned long __tmp; \
    __asm__ volatile ("mrs %0, " #reg : "=r"(__tmp)); \
    __tmp; })

#define _wr_sys(reg, val) ({ \
    __asm__ volatile ("msr " #reg ", %0" :: "r"(val)); })

static inline void isb() {
    asm volatile ("isb");
}

static inline void dsb() {
    asm volatile ("dsb sy");
}
