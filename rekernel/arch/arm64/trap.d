module arch.arm64.trap;

import arch.arm64.sys;
import arch.arm64.regs;
import arch.arm64.vm;

import core.lib;

import bits = core.bits;

import proc;

extern (C) {
    void kernel_exception(Regs* regs) {
        cast(void) regs;
        ulong exc_class = bits.get(SysReg.esr_el1, 31, 26);
        printf("kernel exception: esr: 0x%lx, elr: 0x%lx\n", exc_class, SysReg.elr_el1);
        exit(1);
    }

    void kernel_interrupt(Regs* regs) {
        cast(void) regs;
        printf("kernel interrupt\n");
        exit(1);
    }

    void user_exception(Proc* proc) {
        printf("user exception\n");

        printf("x0: %ld\n", proc.trapframe.regs.x0);

        exit(1);
    }

    void user_interrupt(Proc* proc) {
        printf("user interrupt\n");
        exit(1);
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
