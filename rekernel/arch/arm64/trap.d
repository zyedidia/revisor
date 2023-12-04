module arch.arm64.trap;

import arch.arm64.sys;
import arch.arm64.regs;

extern (C) {
    void kernel_exception(Regs* regs) {
        cast(void) regs;
        printf("kernel exception: esr: %lx, elr: %lx\n", SysReg.esr_el1, SysReg.elr_el1);
    }

    void kernel_interrupt(Regs* regs) {
        cast(void) regs;
        printf("kernel interrupt\n");
    }

    void user_exception() {
        printf("user exception\n");
    }

    void user_interrupt() {
        printf("user interrupt\n");
    }
}
