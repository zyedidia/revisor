module syscall;

import arch.vm;
import arch.sys;

import core.alloc;
import core.lib;
import core.math;

import proc;
import trap;
import vm;
import schedule;

enum Sys {
    FCNTL = 25,
    IOCTL = 29,
    WRITE = 64,
    WRITEV = 66,
    READLINKAT = 78,
    NEWFSTATAT = 79,
    EXIT = 93,
    EXIT_GROUP = 94,
    SET_TID_ADDRESS = 96,
    SET_ROBUST_LIST = 99,
    CLOCK_GETTIME = 113,
    TGKILL = 131,
    RT_SIGACTION = 134,
    RT_SIGPROCMASK = 135,
    UNAME = 160,
    GETPID = 172,
    GETUID = 174,
    GETEUID = 175,
    GETGID = 176,
    GETEGID = 177,
    GETTID = 178,
    BRK = 214,
    MUNMAP = 215,
    MREMAP = 216,
    MMAP = 222,
    MPROTECT = 226,
    PRLIMIT64 = 261,
    GETRANDOM = 278,
    RSEQ = 293,
}

enum Err {
    PERM = -1,
    BADF = -9,
    NOMEM = -12,
    FAULT = -14,
    NOSYS = -38,
}

private bool checkptr(Proc* p, uintptr ptr, usize size) {
    // TODO: improve
    if (ptr >= USER_END) {
        return false;
    }
    return true;
}

uintptr syscall_handler(Proc* p, ulong sysno, ulong a0, ulong a1, ulong a2, ulong a3, ulong a4, ulong a5) {
    uintptr ret;

    switch (sysno) {
    case Sys.GETPID:
        ret = sys_getpid(p);
        break;
    case Sys.BRK:
        ret = sys_brk(p, a0);
        break;
    case Sys.WRITE:
        ret = sys_write(p, cast(int) a0, a1, a2);
        break;
    case Sys.WRITEV:
        ret = sys_writev(p, a0, a1, a2);
        break;
    case Sys.UNAME:
        ret = sys_uname(p, cast(Utsname*) a0);
        break;
    case Sys.EXIT, Sys.EXIT_GROUP:
        sys_exit(p, cast(int) a0);
    case Sys.GETEUID, Sys.GETUID, Sys.GETEGID, Sys.GETGID:
        ret = 1000;
        break;
    case Sys.MPROTECT:
        // TODO: mprotect
        ret = 0;
        break;
    case Sys.MREMAP:
        ret = Err.NOSYS;
        break;
    case Sys.SET_TID_ADDRESS, Sys.SET_ROBUST_LIST, Sys.IOCTL, Sys.PRLIMIT64, Sys.FCNTL:
        // ignored
        ret = 0;
        break;
    default:
        printf("[warning]: unknown syscall: %ld\n", sysno);
        ret = Err.NOSYS;
    }

    return ret;
}

int sys_getpid(Proc* p) {
    return p.pid;
}

struct Iovec {
    uintptr base;
    usize len;
}

ssize sys_writev(Proc* p, ulong a0, ulong a1, ulong a2) {
    int fd = cast(int) a0;
    if (fd != 1 && fd != 2) {
        return Err.BADF;
    }
    uintptr iovp = a1;
    usize iovcnt = a2;
    if (!checkptr(p, iovp, iovcnt * Iovec.sizeof)) {
        return Err.FAULT;
    }
    Iovec[] iov = (cast(Iovec*) iovp)[0 .. iovcnt];
    ssize total = 0;
    // TODO: additional checks on iov
    for (int i = 0; i < iov.length; i++) {
        total += sys_write(p, fd, iov[i].base, iov[i].len);
    }
    return total;
}

ssize sys_write(Proc* p, int fd, uintptr buf, usize size) {
    if (fd != 1 && fd != 2) {
        return Err.BADF;
    }
    if (!checkptr(p, buf, size)) {
        return Err.FAULT;
    }
    ssize i = 0;
    while (size) {
        VmMap map = vm_lookup(p.pt, buf + i);
        if ((map.perm & Perm.READ) == 0) {
            return Err.FAULT;
        }
        ssize n = write(fd, cast(void*) map.ka, min(size, map.size));
        size -= n;
        i += n;
    }
    return i;
}

uintptr sys_brk(Proc* p, uintptr addr) {
    if (!checkptr(p, addr, 1)) {
        return Err.FAULT;
    } else if (addr == 0) {
        return p.brk;
    }
    uintptr oldbrk = ceilpg(p.brk);
    p.brk = addr;
    uint level;
    Pte* pte = p.pt.walk(addr, level);
    if (!pte) {
        return Err.NOMEM;
    } else if (!pte.valid) {
        usize diff = ceilpg(addr) - oldbrk;
        ubyte[] data = kzalloc(diff);
        if (!data)
            return Err.NOMEM;
        if (!p.pt.map_region(oldbrk, ka2pa(data.ptr), data.length, Perm.READ | Perm.WRITE | Perm.USER)) {
            kfree(data);
            return Err.NOMEM;
        }
    } else if ((pte.perm & Perm.USER) == 0) {
        return Err.FAULT;
    }
    return p.brk;
}

noreturn sys_exit(Proc* p, int status) {
    printf("%d: exited\n", p.pid);

    p.block(&exitq, Proc.State.EXITED);

    // should not return
    assert(0);
}

enum {
    UTSNAME_LENGTH = 65,
}

struct Utsname {
    char[UTSNAME_LENGTH] sysname;
    char[UTSNAME_LENGTH] nodename;
    char[UTSNAME_LENGTH] release;
    char[UTSNAME_LENGTH] version_;
    char[UTSNAME_LENGTH] machine;
}

int sys_uname(Proc* p, Utsname* buf) {
    if (!checkptr(p, cast(uintptr) buf, Utsname.sizeof)) {
        return Err.FAULT;
    }

    void addstring(char[] data, string s) {
        memcpy(data.ptr, s.ptr, min(s.length, data.length - 1));
        data[$-1] = '\0';
    }

    char* info = cast(char*) USER_END - PAGESIZE;
    addstring(buf.sysname, "Linux");
    buf.nodename = null;
    addstring(buf.release, "6.0.0-revisor");
    buf.version_ = null;
    buf.machine = null;
    return 0;
}
