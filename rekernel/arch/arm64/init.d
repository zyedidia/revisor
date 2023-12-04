module arch.arm64.init;

import arch.arm64.sys;

extern void ktrap_entry();

void arch_init() {
    // Clear OS lock.
    SysReg.oslar_el1 = 0;
    // Enable FP/SIMD.
    SysReg.cpacr_el1 = SysReg.cpacr_el1 | (0b11 << 20);

    SysReg.vbar_el1 = cast(uintptr) &ktrap_entry;
}
