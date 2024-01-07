module hyper;

import core.alloc;
import core.lib;

import arch.sys;

extern (C) extern uintptr _hypercall(uintptr a0, uintptr a1, uintptr a2, uintptr sysno);

uintptr hypercall(uintptr sysno, uintptr a0 = 0, uintptr a1 = 0, uintptr a2 = 0) {
    return _hypercall(a0, a1, a2, sysno);
}

enum Hyper {
    WRITE      = 0,
    EXIT       = 1,
    OPEN       = 2,
    READ       = 3,
    CLOSE      = 4,
    LSEEK      = 5,
    TIME       = 6,
    FSTAT      = 7,
    GETDENTS64 = 8,
}

__gshared {
    extern (C) extern ubyte _heap_start;
    ubyte* brkp = &_heap_start;
}

extern (C):

void* sbrk(usize incr) {
    if (incr < 0) {
        if (cast(usize) (brkp - &_heap_start) < cast(usize) (-incr)) {
            return cast(void*) -1;
        }
    }
    void* ret = brkp;
    brkp += incr;
    return ret;
}

int open(const char* name, int flags, int mode) {
    if (iska(cast(uintptr) name)) {
        return _open(name, flags, mode);
    }
    ubyte[] buf = kalloc(strlen(name) + 1);
    if (!buf)
        return -1;
    scope(exit) kfree(buf);
    memcpy(buf.ptr, name, buf.length);
    return _open(cast(const char*) buf.ptr, flags, mode);
}

private int _open(const char* name, int flags, int mode) {
    return cast(int) hypercall(Hyper.OPEN, cast(uintptr) name, flags, mode);
}

int close(int file) {
    return cast(int) hypercall(Hyper.CLOSE, file);
}

long lseek(int file, long off, int whence) {
    return cast(long) hypercall(Hyper.LSEEK, file, off, whence);
}

long lseek64(int file, long off, int whence) {
    return cast(long) hypercall(Hyper.LSEEK, file, off, whence);
}

ssize write(int file, char* ptr, int len) {
    if (iska(cast(uintptr) ptr)) {
        return _write(file, ptr, len);
    }
    ubyte[] buf = kalloc(len);
    if (!buf)
        return -1;
    scope(exit) kfree(buf);
    memcpy(buf.ptr, ptr, len);
    return _write(file, cast(char*) buf.ptr, len);
}

private ssize _write(int file, char* ptr, int len) {
    return cast(ssize) hypercall(Hyper.WRITE, file, cast(uintptr) ptr, len);
}

ssize read(int file, char* ptr, int len) {
    if (iska(cast(uintptr) ptr)) {
        return _read(file, ptr, len);
    }
    ubyte[] buf = kalloc(len);
    if (!buf)
        return -1;
    scope(exit) kfree(buf);
    ssize ret = _read(file, cast(char*) buf.ptr, len);
    if (ret > 0) {
        memcpy(ptr, buf.ptr, ret);
    }
    return ret;
}

private ssize _read(int file, char* ptr, int len) {
    return cast(ssize) hypercall(Hyper.READ, file, cast(uintptr) ptr, len);
}

noreturn _exit(int status) {
    hypercall(Hyper.EXIT, status);
    while (1) {}
}

noreturn exit(int status) {
    _exit(status);
}

int isatty(int file) {
    return 1;
}

int fstat(int file, StatHyper* st) {
    return cast(int) hypercall(Hyper.FSTAT, file, cast(uintptr) st);
}

ssize getdents64(int fd, void* dirp, usize count) {
    return cast(ssize) hypercall(Hyper.GETDENTS64, fd, cast(uintptr) dirp, count);
}

int time(ulong* sec, ulong* nano) {
    return cast(int) hypercall(Hyper.TIME, cast(uintptr) sec, cast(uintptr) nano);
}
