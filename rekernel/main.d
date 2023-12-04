module main;

import core.vector;

__gshared Vector!(int) vec;

extern (C) void kmain() {
    printf("arrived in kmain at %p\n", &kmain);

    vec.append(1);
    vec.append(2);
    printf("%d %d\n", vec[0], vec[1]);
}
