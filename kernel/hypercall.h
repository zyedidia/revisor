#pragma once

#include <stdint.h>

static inline uintptr_t hypercall_0(int sysno) {
    register uintptr_t sys asm("rax") = sysno;
    asm volatile("out %%al, %%dx" : "+r"(sys) :: "memory");
    return sys;
}
static inline uintptr_t hypercall_1(int sysno, uintptr_t arg0) {
    register uintptr_t sys asm("rax") = sysno;
    register uintptr_t a0 asm("rdi") = arg0;
    asm volatile("out %%al, %%dx" : "+r"(sys) : "r"(a0) : "memory");
    return sys;
}
static inline uintptr_t hypercall_2(int sysno, uintptr_t arg0, uintptr_t arg1) {
    register uintptr_t sys asm("rax") = sysno;
    register uintptr_t a0 asm("rdi") = arg0;
    register uintptr_t a1 asm("rsi") = arg1;
    asm volatile("out %%al, %%dx" : "+r"(sys) : "r"(a0), "r"(a1) : "memory");
    return sys;
}
static inline uintptr_t hypercall_3(int sysno, uintptr_t arg0, uintptr_t arg1, uintptr_t arg2) {
    register uintptr_t sys asm("rax") = sysno;
    register uintptr_t a0 asm("rdi") = arg0;
    register uintptr_t a1 asm("rsi") = arg1;
    register uintptr_t a2 asm("rdx") = arg2;
    asm volatile("out %%al, %%dx" : "+r"(sys) : "r"(a0), "r"(a1), "r"(a2) : "memory");
    return sys;
}

enum {
    HYP_WRITE = 0,
    HYP_EXIT =  1,
    HYP_OPEN =  2,
    HYP_READ =  3,
    HYP_CLOSE = 4,
    HYP_LSEEK = 5,
};
