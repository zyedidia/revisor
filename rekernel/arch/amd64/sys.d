module arch.amd64.sys;

enum {
    KERNEL_START = 0xffff_8000_0000_0000,
    KTEXT_START = 0xffff_ffff_8000_0000,
}

pragma(inline, true)
uintptr ka2pa(uintptr ka) {
    return ka - KERNEL_START;
}

pragma(inline, true)
uintptr ka2pa(void* ka) {
    return ka2pa(cast(uintptr) ka);
}

pragma(inline, true)
uintptr pa2ka(uintptr pa) {
    return pa + KERNEL_START;
}

pragma(inline, true)
void vm_fence() {
    asm {
        "invlpg";
    }
}
