module object;

alias string = immutable(char)[];
alias usize = typeof(int.sizeof);
alias size_t = usize;

alias noreturn = typeof(*null);

static if ((void*).sizeof == 8) {
    alias uintptr = ulong;
    alias ssize = long;
} else static if ((void*).sizeof == 4) {
    alias uintptr = uint;
    alias ssize = int;
} else {
    static assert(0, "pointer size must be 4 or 8 bytes");
}

pragma(printf)
extern (C) void printf(const char* fmt, ...);

pragma(printf)
extern (C) void eprintf(const char* fmt, ...);

pragma(printf)
extern (C) void panicf(const char* fmt, ...);

enum PAGESIZE = 4096;

struct Empty {}

void ensure(bool b, string msg = "ensure failure", string file = __FILE__, int line = __LINE__) {
    import core.exception : panic;
    if (!b) {
        panic(file, line, msg);
    }
}

bool __equals(scope const string lhs, scope const string rhs) {
    if (lhs.length != rhs.length)
        return false;
    for (usize i = 0; i < lhs.length; i++) {
        if (lhs[i] != rhs[i])
            return false;
    }
    return true;
}

struct Error {
    void* p;
    string function(void* p) error;

    static Error none() {
        return Error();
    }

    bool err() {
        return error != null;
    }

    bool opEquals(const Error o) {
        return o.p == p;
    }

    static Error make(string val)() {
        return Error(cast(void*) val.ptr, (void* p) {
            return val;
        });
    }
}
