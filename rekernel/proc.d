module proc;

import arch.regs;

struct Proc {
    Regs regs;
    Context context;

    int pid;

    Proc* parent;

    Proc* next;
    Proc* prev;
}
