module schedule;

import core.lib;

import arch.regs;

import proc;
import queue;

// Returns the next process available to run, or blocks waiting for a process
// to become available.
Proc* runnable_proc() {
    while (true) {
        Proc* p = runq.pop_back();
        if (p) {
            return p;
        }
    }
}

extern (C) void kswitch(Proc* p, Context* old, Context* new_);

__gshared {
    Queue runq;
    Queue exitq;
    Context scheduler;
    Proc* main;
}

void schedule() {
    while (true) {
        Proc* p = runnable_proc();

        kswitch(p, &scheduler, &p.context);

        if (main.state == Proc.State.EXITED) {
            exit(0);
        }

        if (p.state == Proc.State.RUNNABLE) {
            runq.push_front(p);
        }
    }
}
