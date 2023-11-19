#pragma once

#include <stdint.h>

// Interrupt numbers
#define INT_DIVIDE      0x0         // Divide error
#define INT_DEBUG       0x1         // Debug exception
#define INT_BREAKPOINT  0x3         // Breakpoint
#define INT_OVERFLOW    0x4         // Overflow
#define INT_BOUNDS      0x5         // Bounds check
#define INT_INVALIDOP   0x6         // Invalid opcode
#define INT_DOUBLEFAULT 0x8         // Double fault
#define INT_INVALIDTSS  0xa         // Invalid TSS
#define INT_SEGMENT     0xb         // Segment not present
#define INT_STACK       0xc         // Stack exception
#define INT_GPF         0xd         // General protection fault
#define INT_PAGEFAULT   0xe         // Page fault

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

static inline void lidt(void* p) {
    asm volatile("lidt (%0)" : : "r" (p));
}

static inline void lcr0(uint32_t val) {
    uint64_t xval = val;
    asm volatile("movq %0,%%cr0" : : "r" (xval));
}

static inline uint32_t rcr0(void) {
    uint64_t val;
    asm volatile("movq %%cr0,%0" : "=r" (val));
    return val;
}

// Hardware definitions: C structures and constants for initializing x86
// hardware, particularly gate descriptors (loaded into the interrupt
// descriptor table) and segment descriptors.

// Pseudo-descriptors used for LGDT, LLDT, and LIDT instructions
typedef struct __attribute__((packed, aligned(2))) x86_64_pseudodescriptor {
    uint16_t pseudod_limit;            // Limit
    uint64_t pseudod_base;             // Base address
} x86_64_pseudodescriptor;

// Task state structure defines kernel stack for interrupt handlers
typedef struct __attribute__((packed, aligned(8))) x86_64_taskstate {
    uint32_t ts_reserved0;
    uint64_t ts_rsp[3];
    uint64_t ts_ist[7];
    uint64_t ts_reserved1;
    uint16_t ts_reserved2;
    uint16_t ts_iomap_base;
} x86_64_taskstate;

// Gate descriptor structure defines interrupt handlers
typedef struct x86_64_gatedescriptor {
    uint64_t gd_low;
    uint64_t gd_high;
} x86_64_gatedescriptor;

// Segment bits
#define X86SEG_S        (1UL << 44)
#define X86SEG_P        (1UL << 47)
#define X86SEG_L        (1UL << 53)
#define X86SEG_DB       (1UL << 54)
#define X86SEG_G        (1UL << 55)

// Application segment type bits
#define X86SEG_A        (0x1UL << 40) // Accessed
#define X86SEG_R        (0x2UL << 40) // Readable (code segment)
#define X86SEG_W        (0x2UL << 40) // Writable (data segment)
#define X86SEG_C        (0x4UL << 40) // Conforming (code segment)
#define X86SEG_E        (0x4UL << 40) // Expand-down (data segment)
#define X86SEG_X        (0x8UL << 40) // Executable (== is code segment)

// System segment/interrupt descriptor types
#define X86SEG_TSS        (0x9UL << 40)
#define X86GATE_CALL      (0xCUL << 40)
#define X86GATE_INTERRUPT (0xEUL << 40)
#define X86GATE_TRAP      (0xFUL << 40)

// %cr0 flag bits (useful for lcr0() and rcr0())
#define CR0_PE                  0x00000001      // Protection Enable
#define CR0_MP                  0x00000002      // Monitor coProcessor
#define CR0_EM                  0x00000004      // Emulation
#define CR0_TS                  0x00000008      // Task Switched
#define CR0_ET                  0x00000010      // Extension Type
#define CR0_NE                  0x00000020      // Numeric Errror
#define CR0_WP                  0x00010000      // Write Protect
#define CR0_AM                  0x00040000      // Alignment Mask
#define CR0_NW                  0x20000000      // Not Writethrough
#define CR0_CD                  0x40000000      // Cache Disable
#define CR0_PG                  0x80000000      // Paging

// eflags bits (useful for read_eflags() and write_eflags())
#define EFLAGS_CF               0x00000001      // Carry Flag
#define EFLAGS_PF               0x00000004      // Parity Flag
#define EFLAGS_AF               0x00000010      // Auxiliary carry Flag
#define EFLAGS_ZF               0x00000040      // Zero Flag
#define EFLAGS_SF               0x00000080      // Sign Flag
#define EFLAGS_TF               0x00000100      // Trap Flag
#define EFLAGS_IF               0x00000200      // Interrupt Flag
#define EFLAGS_DF               0x00000400      // Direction Flag
#define EFLAGS_OF               0x00000800      // Overflow Flag
#define EFLAGS_IOPL_MASK        0x00003000      // I/O Privilege Level bitmask
#define EFLAGS_IOPL_0           0x00000000      //   IOPL == 0
#define EFLAGS_IOPL_1           0x00001000      //   IOPL == 1
#define EFLAGS_IOPL_2           0x00002000      //   IOPL == 2
#define EFLAGS_IOPL_3           0x00003000      //   IOPL == 3
#define EFLAGS_NT               0x00004000      // Nested Task
#define EFLAGS_RF               0x00010000      // Resume Flag
#define EFLAGS_VM               0x00020000      // Virtual 8086 mode
#define EFLAGS_AC               0x00040000      // Alignment Check
#define EFLAGS_VIF              0x00080000      // Virtual Interrupt Flag
#define EFLAGS_VIP              0x00100000      // Virtual Interrupt Pending
#define EFLAGS_ID               0x00200000      // ID flag

// struct x86_64_registers
//     A complete set of x86-64 general-purpose registers, plus some
//     special-purpose registers. The order and contents are defined to make
//     it more convenient to use important x86-64 instructions.

typedef struct x86_64_registers {
    uint64_t reg_rax;
    uint64_t reg_rcx;
    uint64_t reg_rdx;
    uint64_t reg_rbx;
    uint64_t reg_rbp;
    uint64_t reg_rsi;
    uint64_t reg_rdi;
    uint64_t reg_r8;
    uint64_t reg_r9;
    uint64_t reg_r10;
    uint64_t reg_r11;
    uint64_t reg_r12;
    uint64_t reg_r13;
    uint64_t reg_r14;
    uint64_t reg_r15;
    uint64_t reg_fs;
    uint64_t reg_gs;

    uint64_t reg_intno;         // (3) Interrupt number and error
    uint64_t reg_err;           // code (optional; supplied by x86
                                // interrupt mechanism)

    uint64_t reg_rip;		// (4) Task status: instruction pointer,
    uint16_t reg_cs;		// code segment, flags, stack
    uint16_t reg_padding2[3];	// in the order required by `iret`
    uint64_t reg_rflags;
    uint64_t reg_rsp;
    uint16_t reg_ss;
    uint16_t reg_padding3[3];
} x86_64_registers;
