module proc;

import arch.regs;
import arch.vm;
import arch.trap;

private enum {
    KSTACK_SIZE = 16 * 1024,
}

struct Proc {
    Trapframe trapframe;
    Context context;

    Pagetable* pt;

    int pid;

    Proc* parent;

    Proc* next;
    Proc* prev;

    align(16) ubyte[KSTACK_SIZE] kstack;
    static assert(kstack.length % 16 == 0);

    // Disable opAssign because it would overflow the stack.
    @disable void opAssign(Proc);

    uintptr kstackp() {
        return cast(uintptr) &kstack[$];
    }
}
