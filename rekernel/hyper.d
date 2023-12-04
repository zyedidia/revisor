module hyper;

extern (C) extern uintptr _hypercall(uintptr a0, uintptr a1, uintptr a2, uintptr sysno);

uintptr hypercall(uintptr sysno, uintptr a0 = 0, uintptr a1 = 0, uintptr a2 = 0) {
    return _hypercall(a0, a1, a2, sysno);
}

enum Hyper {
    WRITE = 0,
    EXIT  = 1,
    OPEN  = 2,
    READ  = 3,
    CLOSE = 4,
    LSEEK = 5,
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
    return cast(int) hypercall(Hyper.OPEN, cast(uintptr) name, flags, mode);
}

int close(int file) {
    return cast(int) hypercall(Hyper.CLOSE, file);
}

int lseek(int file, ulong off, int whence) {
    return cast(int) hypercall(Hyper.LSEEK, file, off, whence);
}

int lseek64(int file, ulong off, int whence) {
    return cast(int) hypercall(Hyper.LSEEK, file, off, whence);
}

int write(int file, char* ptr, int len) {
    return cast(int) hypercall(Hyper.WRITE, file, cast(uintptr) ptr, len);
}

int read(int file, char* ptr, int len) {
    return cast(int) hypercall(Hyper.READ, file, cast(uintptr) ptr, len);
}

noreturn exit(int status) {
    hypercall(Hyper.EXIT, status);
    while (1) {}
}

int isatty(int file) {
    return 1;
}

int fstat(int file, void* st) {
    return -1;
}
