module init;

__gshared {
    extern (C) ubyte* hypcall_dev = cast(ubyte*) 0x4000;
    usize memory_size;
}

extern (C) void kinit(usize memsz) {
    memory_size = memsz;
    // arch_init();
}
