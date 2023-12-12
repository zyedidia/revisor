module arch.amd64.trap;

import arch.amd64.regs;
import arch.amd64.sys;
import arch.amd64.init;

import proc;
import syscall;

struct TrapInfo {
    uintptr proc_tf_end;
    uintptr kernel_sp;
    uintptr saved_sp;
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

    void exception(Trapframe* tf) {
        panicf("exception rip: 0x%lx, intno: %ld, err: %ld, cr2: 0x%lx\n", tf.epc, tf.intno, tf.err, rd_cr2());
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
