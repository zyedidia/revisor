module arch.arm64.init;

import arch.arm64.sys;
import arch.arm64.gic;

extern (C) extern void ktrap_entry();

void arch_init() {
    // Clear OS lock.
    SysReg.oslar_el1 = 0;
    // Enable FP/SIMD.
    SysReg.cpacr_el1 = SysReg.cpacr_el1 | (0b11 << 20);

    SysReg.vbar_el1 = cast(uintptr) &ktrap_entry;

    gic_init();
    enum TIMER_IRQ = 30;
    gic_set_config(TIMER_IRQ, GIC_ICFGR_EDGE);
    gic_set_priority(TIMER_IRQ, 0);
    gic_set_core(TIMER_IRQ, 0x00);
    gic_clear(TIMER_IRQ);
    gic_enable(TIMER_IRQ);
}
