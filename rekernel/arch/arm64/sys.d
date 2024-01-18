module arch.arm64.sys;

const char[] GenSysReg(string name) = GenSysRegRdOnly!(name) ~ GenSysRegWrOnly!(name);
const char[] GenSysRegRdOnly(string name) =
`pragma(inline, true) ` ~
`static uintptr ` ~ name ~ `() {
    uintptr val;
    asm {
        "mrs %0, ` ~ name ~ `" : "=r"(val);
    }
    return val;
}`;
const char[] GenSysRegWrOnly(string name) =
`pragma(inline, true) ` ~
`static void ` ~ name ~ `(uintptr v) {
    asm {
        "msr ` ~ name ~ `, %0" : : "r"(v);
    }
}`;

struct SysReg {
    mixin(GenSysRegRdOnly!("currentel"));

    mixin(GenSysReg!("sctlr_el1"));
    mixin(GenSysReg!("sp_el1"));
    mixin(GenSysReg!("ttbr0_el1"));
    mixin(GenSysReg!("ttbr1_el1"));
    mixin(GenSysReg!("tcr_el1"));
    mixin(GenSysReg!("mair_el1"));
    mixin(GenSysReg!("tpidr_el1"));
    mixin(GenSysReg!("vbar_el1"));
    mixin(GenSysReg!("elr_el1"));
    mixin(GenSysReg!("spsr_el1"));
    mixin(GenSysReg!("esr_el1"));
    mixin(GenSysReg!("far_el1"));
    mixin(GenSysReg!("mdscr_el1"));
    mixin(GenSysRegRdOnly!("mpidr_el1"));
    mixin(GenSysRegRdOnly!("isr_el1"));
    mixin(GenSysRegWrOnly!("oslar_el1"));
    mixin(GenSysReg!("cpacr_el1"));

    mixin(GenSysReg!("dbgbcr0_el1"));
    mixin(GenSysReg!("dbgbvr0_el1"));
    mixin(GenSysReg!("dbgwcr0_el1"));
    mixin(GenSysReg!("dbgwvr0_el1"));

    mixin(GenSysReg!("cntfrq_el0"));
    mixin(GenSysRegRdOnly!("cntpct_el0"));
    mixin(GenSysRegRdOnly!("cntvct_el0"));
    mixin(GenSysReg!("cntp_ctl_el0"));
    mixin(GenSysReg!("cntp_tval_el0"));
    mixin(GenSysReg!("cntv_ctl_el0"));
    mixin(GenSysReg!("cntv_tval_el0"));
    mixin(GenSysReg!("pmccntr_el0"));
    mixin(GenSysReg!("pmccfiltr_el0"));
    mixin(GenSysReg!("pmcntenset_el0"));
    mixin(GenSysReg!("pmcr_el0"));

    mixin(GenSysReg!("daif"));

    // GICv3 CPUIF registers
    mixin(GenSysReg!("icc_sre_el1"));
    mixin(GenSysReg!("icc_pmr_el1"));
    mixin(GenSysReg!("icc_ctlr_el1"));
    mixin(GenSysReg!("icc_igrpen0_el1"));
    mixin(GenSysReg!("icc_igrpen1_el1"));
    mixin(GenSysReg!("icc_bpr0_el1"));
    mixin(GenSysReg!("icc_bpr1_el1"));
    mixin(GenSysRegRdOnly!("icc_iar0_el1"));
    mixin(GenSysRegRdOnly!("icc_iar1_el1"));
    mixin(GenSysRegWrOnly!("icc_eoir0_el1"));
}

enum {
    USER_END     = 0x0001_0000_0000_0000,
    KERNEL_START = 0xffff_0000_0000_0000,

    SPSR_EL0 = 0,
}

enum Exception {
    SMC   = 0b010111,
    SVC   = 0b010101,
    HVC   = 0b010110,
    BRKPT = 0b110000,
    WCHPT = 0b110100,
    SS    = 0b110010,

    DATA_ABORT_LOWER = 0b100100,
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
        "dsb ish" ::: "memory";
        "tlbi vmalle1" ::: "memory";
        "dsb ish" ::: "memory";
        "isb" ::: "memory";
    }
}

pragma(inline, true)
void isb() {
    asm {
        "isb";
    }
}
