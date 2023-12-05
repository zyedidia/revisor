module arch.amd64.trap;

import arch.amd64.regs;

struct TrapInfo {
    Regs gpr;

    // interrupt number and error
    ulong intno;
    ulong err;

    // task status info in order required by iret
    ulong rip;
    ushort cs;
    ushort[3] _p1;
    ulong rflags;
    ulong rsp;
    ushort ss;
    ushort[3] _p2;
}
