module arch.amd64.regs;

struct Regs {
    ulong rax;
    ulong rcx;
    ulong rdx;
    ulong rbx;
    ulong rbp;
    ulong rsi;
    ulong rdi;
    ulong r8;
    ulong r9;
    ulong r10;
    ulong r11;
    ulong r12;
    ulong r13;
    ulong r14;
    ulong r15;
    ulong fs;
    ulong gs;
}

struct Context {
    ulong rsp;
    ulong rbx;
    ulong rbp;
    ulong r12;
    ulong r13;
    ulong r14;
    ulong r15;
}
