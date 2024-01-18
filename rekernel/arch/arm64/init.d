module arch.arm64.init;

import arch.arm64.sys;
import arch.arm64.gic;
import arch.arm64.timer;

import bits = core.bits;

extern (C) extern void ktrap_entry();

void arch_init() {
    // Clear OS lock.
    SysReg.oslar_el1 = 0;
    // Enable FP/SIMD.
    SysReg.cpacr_el1 = SysReg.cpacr_el1 | (0b11 << 20);

    SysReg.vbar_el1 = cast(uintptr) &ktrap_entry;

    uint affinity = cast(uint) bits.get(SysReg.mpidr_el1, 24, 0);
    gic_init(affinity, GIC_DIST_BASE, GIC_REDIST_BASE);

    timer_intr(TIME_SLICE);
}
