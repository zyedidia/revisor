module arch.amd64.sys;

enum {
    KERNEL_START = 0xffff_8000_0000_0000,
    KTEXT_START = 0xffff_ffff_8000_0000,

    USER_END = 0x0000_8000_0000_0000,
}

pragma(inline, true)
uintptr ka2pa(uintptr ka) {
    return ka - KERNEL_START;
}

pragma(inline, true)
uintptr ka2pa(void* ka) {
    return ka2pa(cast(uintptr) ka);
}

pragma(inline, true)
uintptr pa2ka(uintptr pa) {
    return pa + KERNEL_START;
}

pragma(inline, true)
uintptr iska(uintptr addr) {
    return addr >= KERNEL_START;
}

pragma(inline, true)
void vm_fence() {
    asm {
        "invlpg 0";
    }
}

align(2) struct PseudoDescriptor {
    align(1):
    ushort limit;
    ulong base;
}

align(8) struct TaskState {
    align(1):
    uint reserved0;
    ulong[3] rsp;
    ulong[7] ist;
    ulong reserved1;
    ushort reserved2;
    ushort iomap_base;
}

struct GateDescriptor {
    ulong low;
    ulong high;
}

pragma(inline, true)
void wr_msr(uint msr, ulong val) {
    asm {
        "wrmsr" :: "c" (msr), "a" (cast(uint) val), "d" (val >> 32);
    }
}

pragma(inline, true)
void wr_idt(void* p) {
    asm {
        "lidt (%0)" :: "r"(p);
    }
}

pragma(inline, true)
void wr_cr0(uint val) {
    asm {
        "movq %0, %%cr0" :: "r"(cast(ulong) val);
    }
}

pragma(inline, true)
void wr_cr3(uintptr val) {
    asm {
        "" ::: "memory";
        "movq %0, %%cr3" :: "r"(val) : "memory";
    }
}

pragma(inline, true)
uintptr rd_cr3() {
    uintptr val;
    asm {
        "movq %%cr3, %0" : "=r"(val);
    }
    return val;
}

pragma(inline, true)
uintptr rd_cr2() {
    uintptr val;
    asm {
        "movq %%cr2, %0" : "=r"(val);
    }
    return val;
}

pragma(inline, true)
uint rd_cr0() {
    ulong val;
    asm {
        "movq %%cr0, %0" : "=r"(val);
    }
    return cast(uint) val;
}

enum {
    SEGSEL_KERN_CODE = 0x8,
    SEGSEL_APP_CODE  = 0x10,
    SEGSEL_KERN_DATA = 0x18,
    SEGSEL_APP_DATA  = 0x20,
    SEGSEL_TASKSTATE = 0x28,

    X86SEG_S = 1UL << 44,
    X86SEG_P = 1UL << 47,
    X86SEG_L = 1UL << 53,
    X86SEG_DB = 1UL << 54,
    X86SEG_G = 1UL << 55,

    // Application segment type bits
    X86SEG_A = 0x1UL << 40, // Accessed
    X86SEG_R = 0x2UL << 40, // Readable (code segment)
    X86SEG_W = 0x2UL << 40, // Writable (data segment)
    X86SEG_C = 0x4UL << 40, // Conforming (code segment)
    X86SEG_E = 0x4UL << 40, // Expand-down (data segment)
    X86SEG_X = 0x8UL << 40, // Executable (== is code segment)

    // System segment/interrupt descriptor types
    X86SEG_TSS        = 0x9UL << 40,
    X86GATE_CALL      = 0xCUL << 40,
    X86GATE_INTERRUPT = 0xEUL << 40,
    X86GATE_TRAP      = 0xFUL << 40,

    // Interrupt numbers
    INT_DIVIDE      = 0x0,        // Divide error
    INT_DEBUG       = 0x1,        // Debug exception
    INT_BREAKPOINT  = 0x3,        // Breakpoint
    INT_OVERFLOW    = 0x4,        // Overflow
    INT_BOUNDS      = 0x5,        // Bounds check
    INT_INVALIDOP   = 0x6,        // Invalid opcode
    INT_DOUBLEFAULT = 0x8,        // Double fault
    INT_INVALIDTSS  = 0xa,        // Invalid TSS
    INT_SEGMENT     = 0xb,        // Segment not present
    INT_STACK       = 0xc,        // Stack exception
    INT_GPF         = 0xd,        // General protection fault
    INT_PAGEFAULT   = 0xe,        // Page fault

    MSR_IA32_APIC_BASE           = 0x1B,
    MSR_IA32_MTRR_CAP            = 0xFE,
    MSR_IA32_MTRR_BASE           = 0x200,
    MSR_IA32_MTRR_FIX64K_00000   = 0x250,
    MSR_IA32_MTRR_FIX16K_80000   = 0x258,
    MSR_IA32_MTRR_FIX16K_A0000   = 0x259,
    MSR_IA32_MTRR_FIX4K_C0000    = 0x268,
    MSR_IA32_MTRR_DEF_TYPE       = 0x2FF,
    MSR_IA32_EFER                = 0xC0000080U,
    MSR_IA32_FS_BASE             = 0xC0000100U,
    MSR_IA32_GS_BASE             = 0xC0000101U,
    MSR_IA32_KERNEL_GS_BASE      = 0xC0000102U,
    MSR_IA32_STAR                = 0xC0000081U,
    MSR_IA32_LSTAR               = 0xC0000082U,
    MSR_IA32_FMASK               = 0xC0000084U,

    // %cr0 flag bits (useful for lcr0() and rcr0())
    CR0_PE                  = 0x00000001,     // Protection Enable
    CR0_MP                  = 0x00000002,     // Monitor coProcessor
    CR0_EM                  = 0x00000004,     // Emulation
    CR0_TS                  = 0x00000008,     // Task Switched
    CR0_ET                  = 0x00000010,     // Extension Type
    CR0_NE                  = 0x00000020,     // Numeric Errror
    CR0_WP                  = 0x00010000,     // Write Protect
    CR0_AM                  = 0x00040000,     // Alignment Mask
    CR0_NW                  = 0x20000000,     // Not Writethrough
    CR0_CD                  = 0x40000000,     // Cache Disable
    CR0_PG                  = 0x80000000,     // Paging

    // eflags bits
    EFLAGS_CF              = 0x00000001,     // Carry Flag
    EFLAGS_PF              = 0x00000004,     // Parity Flag
    EFLAGS_AF              = 0x00000010,     // Auxiliary carry Flag
    EFLAGS_ZF              = 0x00000040,     // Zero Flag
    EFLAGS_SF              = 0x00000080,     // Sign Flag
    EFLAGS_TF              = 0x00000100,     // Trap Flag
    EFLAGS_IF              = 0x00000200,     // Interrupt Flag
    EFLAGS_DF              = 0x00000400,     // Direction Flag
    EFLAGS_OF              = 0x00000800,     // Overflow Flag
    EFLAGS_IOPL_MASK       = 0x00003000,     // I/O Privilege Level bitmask
    EFLAGS_IOPL_0          = 0x00000000,     //   IOPL == 0
    EFLAGS_IOPL_1          = 0x00001000,     //   IOPL == 1
    EFLAGS_IOPL_2          = 0x00002000,     //   IOPL == 2
    EFLAGS_IOPL_3          = 0x00003000,     //   IOPL == 3
    EFLAGS_NT              = 0x00004000,     // Nested Task
    EFLAGS_RF              = 0x00010000,     // Resume Flag
    EFLAGS_VM              = 0x00020000,     // Virtual 8086 mode
    EFLAGS_AC              = 0x00040000,     // Alignment Check
    EFLAGS_VIF             = 0x00080000,     // Virtual Interrupt Flag
    EFLAGS_VIP             = 0x00100000,     // Virtual Interrupt Pending
    EFLAGS_ID              = 0x00200000,     // ID flag
}
