module arch.arm64.trap;

import arch.arm64.sys;
import arch.arm64.regs;
import arch.arm64.vm;

import proc;

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

struct Trapframe {
    uintptr sp;   // kernel stack pointer
    uintptr epc;  // program counter to return to after the trap
    uintptr tp;   // thread pointer
    Regs regs;
}

extern (C) noreturn userret(Proc* p);

noreturn usertrapret(Proc* p) {
    SysReg.spsr_el1 = SPSR_EL0;

    p.trapframe.sp = p.kstackp();
    p.trapframe.tp = SysReg.tpidr_el1;
    SysReg.elr_el1 = p.trapframe.epc;
    SysReg.tpidr_el1 = cast(uintptr) p;

    wrpt(p.pt);

    userret(p);
}
