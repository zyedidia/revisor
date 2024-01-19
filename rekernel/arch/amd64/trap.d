module arch.amd64.trap;

import arch.amd64.regs;
import arch.amd64.sys;
import arch.amd64.init;

import proc;
import syscall;
import trap;
import hyper;

void irq_on() {
    asm {
        "sti";
    }
}

void irq_off() {
    asm {
        "cli";
    }
}

bool irq_enabled() {
    return false;
}

struct TrapInfo {
    uintptr proc_tf_end;
    uintptr kernel_sp;
    uintptr saved_sp;
    uintptr scratch;
}

__gshared TrapInfo info;

struct Trapframe {
    Regs regs;

    // interrupt number and error
    ulong intno;
    ulong err;

    // task status info in order required by iret
    ulong epc;
    ushort cs;
    ushort[3] _p1;
    ulong rflags;
    ulong rsp;
    ushort ss;
    ushort[3] _p2;

    void user_sp(uintptr val) {
        rsp = val;
    }

    uintptr user_sp() {
        return rsp;
    }

    void setup() {
        cs = SEGSEL_APP_CODE | 3;
        ss = SEGSEL_APP_DATA | 3;
        regs.gs = SEGSEL_APP_DATA | 3;
        regs.fs = SEGSEL_APP_DATA | 3;
        rflags = EFLAGS_IF;
    }
}

extern (C) {
    void syscall_amd64(Proc* p) {
        Regs* r = &p.trapframe.regs;
        r.rax = syscall_handler(p, r.rax, r.rdi, r.rsi, r.rdx, r.r10, r.r8, r.r9);
        usertrapret(p);
    }

    void kernel_exception(Trapframe* tf) {
        switch (tf.intno) {
        case INT_IRQ + IRQ_TIMER:
            break;
        default:
            panicf("kernel exception rip: 0x%lx, intno: %ld, err: %ld, cr2: 0x%lx\n", tf.epc, tf.intno, tf.err, rd_cr2());
        }
    }

    void user_exception(Proc* p) {
        Trapframe* tf = &p.trapframe;

        switch (tf.intno) {
        case INT_IRQ + IRQ_TIMER:
            lapic.ack();
            irq(Irq.TIMER);
            break;
        case INT_IRQ + IRQ_SIGNAL:
            clear_signal(IRQ_SIGNAL);
            lapic.ack();
            if (signal(p, 0) == Action.EXIT) {
                sys_exit(p, 1);
            }
            break;
        default:
            panicf("user exception rip: 0x%lx, intno: %ld, err: %ld, cr2: 0x%lx\n", tf.epc, tf.intno, tf.err, rd_cr2());
        }

        usertrapret(p);
    }

    noreturn userret(Trapframe* tf);
}

noreturn usertrapret(Proc* p) {
    vm_fence();

    info.proc_tf_end = cast(uintptr) p + p.trapframe.sizeof;
    info.kernel_sp = p.kstackp();
    wr_msr(MSR_IA32_GS_BASE, cast(uintptr) &info);

    userret(&p.trapframe);
}
