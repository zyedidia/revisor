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

    void ret(ulong val) {
        rax = val;
    }
}

struct Context {
    ulong rsp;
    ulong r15;
    ulong r14;
    ulong r13;
    ulong r12;
    ulong rbx;
    ulong rbp;

    this(uintptr lr, uintptr sp) {
        this.rsp = sp - 16;
        *(cast(ulong*) this.rsp) = lr;
    }
}
