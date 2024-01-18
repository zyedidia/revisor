module main;

import arch.regs;
import arch.trap;

import arch.arm64.sys;

import core.lib;

import schedule : schedule, runq, main;
import proc;
import config;

__gshared Context old;

extern (C) void kswitch(Proc* p, Context* old, Context* new_);

extern (C) void kmain(int argc, immutable(char)** argv) {
    if (argc == 0) {
        eprintf("error: no user application given\n");
        return;
    }

    Proc* p = Proc.make_from_file(argv[0], argc, argv);
    if (!p) {
        eprintf("error: could not execute %s\n", argv[0]);
        return;
    }

    main = p;
    runq.push_front(p);

    schedule();
}
