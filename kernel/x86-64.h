#pragma once

#include <stdint.h>

#define MSR_IA32_APIC_BASE           0x1B
#define MSR_IA32_MTRR_CAP            0xFE
#define MSR_IA32_MTRR_BASE           0x200
#define MSR_IA32_MTRR_FIX64K_00000   0x250
#define MSR_IA32_MTRR_FIX16K_80000   0x258
#define MSR_IA32_MTRR_FIX16K_A0000   0x259
#define MSR_IA32_MTRR_FIX4K_C0000    0x268
#define MSR_IA32_MTRR_DEF_TYPE       0x2FF
#define MSR_IA32_EFER                0xC0000080U
#define MSR_IA32_FS_BASE             0xC0000100U
#define MSR_IA32_GS_BASE             0xC0000101U
#define MSR_IA32_KERNEL_GS_BASE      0xC0000102U
#define MSR_IA32_STAR                0xC0000081U
#define MSR_IA32_LSTAR               0xC0000082U
#define MSR_IA32_FMASK               0xC0000084U

static inline void wrmsr(uint32_t msr, uint64_t x) {
    asm volatile("wrmsr" : : "c" (msr), "a" ((uint32_t) x), "d" (x >> 32));
}
