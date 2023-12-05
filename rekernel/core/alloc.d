module core.alloc;

import core.emplace;
import core.lib : malloc, memset, free;

ubyte[] kalloc(usize sz) {
    ubyte* p = cast(ubyte*) malloc(sz);
    if (!p)
        return null;
    return p[0 .. sz];
}

ubyte[] kzalloc(usize sz) {
    ubyte[] mem = kalloc(sz);
    if (!mem)
        return null;
    memset(mem.ptr, 0, mem.length);
    return mem;
}

T* knew(T)() {
    T* p = cast(T*) malloc(T.sizeof);
    if (!p) {
        return null;
    }
    if (!emplace_init(p)) {
        free(p);
        return null;
    }
    return p;
}

T[] kallocarray(T)(usize nelem) {
    T* p = cast(T*) malloc(T.sizeof * nelem);
    if (!p) {
        return null;
    }
    return p[0 .. nelem];
}

void kfree(T)(T* ptr) if (is(T == struct)) {
    static if (HasDtor!(T)) {
        ptr.__xdtor();
    }
    free(ptr);
}

void kfree(T)(T[] arr) {
    static if (HasDtor!(T)) {
        foreach (ref val; arr) {
            val.__xdtor();
        }
    }
    free(arr.ptr);
}
