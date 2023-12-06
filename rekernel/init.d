module init;

import arch.init;
import arch.sys : pa2ka;

import core.lib;

__gshared {
    extern (C) ubyte* hypcall_dev = cast(ubyte*) pa2ka(0x4000);
    usize memory_size;
}

alias PutcFn = void function(void*, char);

extern (C) void init_printf(void* putp, PutcFn putcf);

private void putc(void* _, char c) {
    assert(fwrite(&c, 1, 1, stdout) == 1);
}

extern (C) void kinit(usize memsz) {
    init_printf(null, &putc);

    memory_size = memsz;
    arch_init();
}
