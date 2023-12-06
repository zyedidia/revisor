module main;

import arch.regs;

import proc;

__gshared Context old;

extern (C) void kswitch(Proc* p, Context* old, Context* new_);

extern (C) void kmain() {
    printf("arrived in kmain at %p\n", &kmain);

    Proc* p = Proc.make_from_file("user/hello.elf");
    if (!p) {
        printf("failed to make proc\n");
        return;
    }

    kswitch(p, &old, &p.context);
}
