module main;

import arch.regs;

import proc;

__gshared Context old;

extern (C) void kswitch(Proc* p, Context* old, Context* new_);

extern (C) void kmain(int argc, char** argv) {
    printf("arrived in kmain at %p\n", &kmain);

    if (argc == 0) {
        printf("error: no user application given\n");
        return;
    }

    Proc* p = Proc.make_from_file(argv[0]);
    if (!p) {
        printf("failed to make proc\n");
        return;
    }

    kswitch(p, &old, &p.context);
}
