module object;

alias string = immutable(char)[];
alias usize = typeof(int.sizeof);
alias size_t = usize;

alias noreturn = typeof(*null);

static if ((void*).sizeof == 8) {
    alias uintptr = ulong;
} else static if ((void*).sizeof == 4) {
    alias uintptr = uint;
} else {
    static assert(0, "pointer size must be 4 or 8 bytes");
}

pragma(printf)
extern (C) void printf(const char* fmt, ...);

enum PAGESIZE = 4096;
