module arch.arm64.timer;

import arch.arm64.sys;

void timer_setup() {
    // Enable cycle counter.
    SysReg.pmcr_el0 = 1;
    SysReg.pmcntenset_el0 = 1 << 31;
}

ulong timer_freq() {
    return SysReg.cntfrq_el0;
}

ulong timer_time() {
    return SysReg.cntpct_el0;
}

ulong timer_cycles() {
    return SysReg.pmccntr_el0;
}

void timer_intr(ulong us) {
    SysReg.cntp_tval_el0 = timer_freq() / 1_000_000 * us;
    SysReg.cntp_ctl_el0 = 1;
}
