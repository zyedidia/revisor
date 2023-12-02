#pragma once

#include <stdint.h>

extern volatile uint8_t* hypcall_dev;
extern uintptr_t hypercall(uintptr_t a0, uintptr_t a1, uintptr_t a2, uintptr_t sysno, volatile uint8_t* dev);

static inline uintptr_t hypercall3(uintptr_t arg0, uintptr_t arg1, uintptr_t arg2, uintptr_t sysno) {
    return hypercall(arg0, arg1, arg2, sysno, hypcall_dev);
}

static inline uintptr_t hypercall2(uintptr_t arg0, uintptr_t arg1, uintptr_t sysno) {
    return hypercall3(arg0, arg1, 0, sysno);
}

static inline uintptr_t hypercall1(uintptr_t arg0, uintptr_t sysno) {
    return hypercall3(arg0, 0, 0, sysno);
}

static inline uintptr_t hypercall0(uintptr_t sysno) {
    return hypercall3(0, 0, 0, sysno);
}
