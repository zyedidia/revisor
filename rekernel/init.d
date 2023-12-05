module init;

import arch.init;
import arch.sys : pa2ka;

__gshared {
    extern (C) ubyte* hypcall_dev = cast(ubyte*) pa2ka(0x4000);
    usize memory_size;
}

extern (C) void kinit(usize memsz) {
    memory_size = memsz;
    arch_init();
}
