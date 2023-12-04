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
    mixin(GenSysRegWrOnly!("oslar_el1"));
    mixin(GenSysReg!("cpacr_el1"));

    mixin(GenSysReg!("dbgbcr0_el1"));
    mixin(GenSysReg!("dbgbvr0_el1"));
    mixin(GenSysReg!("dbgwcr0_el1"));
    mixin(GenSysReg!("dbgwvr0_el1"));

    mixin(GenSysReg!("cntfrq_el0"));
    mixin(GenSysRegRdOnly!("cntpct_el0"));
    mixin(GenSysReg!("cntp_ctl_el0"));
    mixin(GenSysReg!("cntp_tval_el0"));
    mixin(GenSysReg!("pmccntr_el0"));
    mixin(GenSysReg!("pmccfiltr_el0"));
    mixin(GenSysReg!("pmcntenset_el0"));
    mixin(GenSysReg!("pmcr_el0"));

    mixin(GenSysReg!("daif"));
}