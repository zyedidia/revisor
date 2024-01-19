module arch.arm64.trap;

import arch.arm64.sys;
import arch.arm64.regs;
import arch.arm64.vm;
import arch.arm64.gic;
import arch.arm64.timer;

import core.lib;

import bits = core.bits;

import proc;
import trap;
import syscall;
import hyper;

void irq_on() {
    SysReg.daif = bits.write(SysReg.daif, 9, 6, 0b0000);
}

void irq_off() {
    SysReg.daif = bits.write(SysReg.daif, 9, 6, 0b1111);
}

bool irq_enabled() {
    return ((SysReg.daif >> 6) & 0b11) != 0b11;
}

extern (C) {
    void kernel_exception(Regs* regs) {
        cast(void) regs;
        ulong exc_class = bits.get(SysReg.esr_el1, 31, 26);
        panicf("kernel exception: esr: 0x%lx, elr: 0x%lx, far: 0x%lx\n", exc_class, SysReg.elr_el1, SysReg.far_el1);
    }

    void kernel_interrupt(Regs* regs) {
        cast(void) regs;

        panicf("kernel interrupt\n");
    }

    void user_exception(Proc* p) {
        ulong exc_class = bits.get(SysReg.esr_el1, 31, 26);

        switch (exc_class) {
        case Exception.SVC:
            Regs* r = &p.trapframe.regs;
            r.x0 = syscall_handler(p, r.x8, r.x0, r.x1, r.x2, r.x3, r.x4, r.x5);
            break;
        case Exception.DATA_ABORT_LOWER:
            ubyte dir = SysReg.esr_el1 & 1;
            pagefault(p, SysReg.far_el1, dir == 1 ? Fault.WRITE : Fault.READ);
            break;
        default:
            printf("[unhandled user exception]: esr: 0x%lx, elr: 0x%lx, far: 0x%lx\n", exc_class, SysReg.elr_el1, SysReg.far_el1);
            unhandled(p);
        }

        usertrapret(p);
    }

    void user_interrupt(Proc* p) {
        ulong id = SysReg.icc_iar0_el1;

        Action action;
        switch (id) {
        case GIC_VIRT_TIMER_ID:
            timer_intr(TIME_SLICE); // requeue timer interrupt
            action = irq(Irq.TIMER);
            break;
        case GIC_SIGNAL_ID:
            action = signal(p, id);
            clear_signal(cast(uint) id);
            break;
        default:
            panicf("unknown interrupt\n");
        }

        SysReg.icc_eoir0_el1 = id;
        isb();

        switch (action) {
        case Action.EXIT:
            sys_exit(p, 1);
        case Action.YIELD:
            break;
        default:
        }

        usertrapret(p);
    }
}

struct Trapframe {
    uintptr sp;   // kernel stack pointer
    uintptr epc;  // program counter to return to after the trap
    uintptr tp;   // thread pointer
    Regs regs;

    void user_sp(uintptr val) {
        regs.sp = val;
    }

    uintptr user_sp() {
        return regs.sp;
    }

    void setup() {}
}

extern (C) noreturn userret(Proc* p);

noreturn usertrapret(Proc* p) {
    SysReg.spsr_el1 = SPSR_EL0;

    p.trapframe.sp = p.kstackp();
    p.trapframe.tp = SysReg.tpidr_el1;
    SysReg.elr_el1 = p.trapframe.epc;
    SysReg.tpidr_el1 = cast(uintptr) p;

    vm_fence();

    userret(p);
}
