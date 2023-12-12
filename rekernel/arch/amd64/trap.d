module arch.amd64.trap;

import arch.amd64.regs;
import arch.amd64.sys;

import proc;

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

extern (C) void exception(Trapframe* frame) {
    panicf("exception at %lx, intno: %ld, err: %ld\n", frame.epc, frame.intno, frame.err);
}

extern (C) noreturn userret(Trapframe* tf);

noreturn usertrapret(Proc* p) {
    vm_fence();

    userret(&p.trapframe);
}
