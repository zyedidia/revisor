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
import file;

enum Sys {
    FCNTL = 25,
    IOCTL = 29,
    OPENAT = 56,
    CLOSE = 57,
    LSEEK = 62,
    READ = 63,
    WRITE = 64,
    READV = 65,
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
    SYSINFO = 179,
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
    NOENT = 2,
    BADF = -9,
    NOMEM = -12,
    FAULT = -14,
    NFILE = -23,
    NOSYS = -38,
}

private bool checkptr(Proc* p, uintptr ptr, usize size) {
    // TODO: improve
    if (ptr >= USER_END) {
        return false;
    }
    return true;
}

private bool checkstr(Proc* p, uintptr str) {
    // TODO: improve
    return checkptr(p, str, 1);
}

uintptr syscall_handler(Proc* p, ulong sysno, ulong a0, ulong a1, ulong a2, ulong a3, ulong a4, ulong a5) {
    uintptr ret;

    // printf("syscall: %ld\n", sysno);

    switch (sysno) {
    case Sys.GETPID:
        ret = sys_getpid(p);
        break;
    case Sys.BRK:
        ret = sys_brk(p, a0);
        break;
    case Sys.LSEEK:
        ret = sys_lseek(p, cast(int) a0, a1, cast(int) a2);
        break;
    case Sys.READ:
        ret = sys_read(p, cast(int) a0, a1, a2);
        break;
    case Sys.WRITE:
        ret = sys_write(p, cast(int) a0, a1, a2);
        break;
    case Sys.WRITEV:
        ret = sys_writev(p, a0, a1, a2);
        break;
    case Sys.OPENAT:
        ret = sys_openat(p, cast(int) a0, a1, cast(int) a2, cast(int) a3);
        break;
    case Sys.CLOSE:
        ret = sys_close(p, cast(int) a0);
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
    case Sys.MREMAP, Sys.SYSINFO:
        // not implemented
        ret = Err.NOSYS;
        break;
    case Sys.MMAP:
        ret = sys_mmap(p, a0, a1, cast(int) a2, cast(int) a3, cast(int) a4, cast(long) a5);
        break;
    case Sys.MUNMAP:
        ret = sys_munmap(p, a0, a1);
        break;
    case Sys.SET_TID_ADDRESS, Sys.SET_ROBUST_LIST, Sys.IOCTL, Sys.PRLIMIT64, Sys.FCNTL:
        // ignored
        ret = 0;
        break;
    default:
        printf("[warning]: unknown syscall: %ld\n", sysno);
        ret = Err.NOSYS;
    }

    // printf("ret = %lx\n", ret);

    return ret;
}

int sys_getpid(Proc* p) {
    return p.pid;
}

int sys_openat(Proc* p, int dirfd, uintptr pathname, int flags, int mode) {
    if (dirfd != AT_FDCWD) {
        return Err.BADF;
    }
    if (!checkstr(p, pathname)) {
        return Err.FAULT;
    }
    int fd;
    VFile* vf = p.fdtable.alloc(fd);
    if (!vf) {
        return Err.NFILE;
    }
    int err = file_new(vf, cast(char*) pathname, flags, mode);
    if (err < 0) {
        p.fdtable.remove(fd);
        return err;
    }
    return fd;
}

int sys_close(Proc* p, int fd) {
    // TODO: file refcount
    if (!p.fdtable.remove(fd)) {
        return Err.BADF;
    }
    return 0;
}

ssize sys_lseek(Proc* p, int fd, ssize off, int whence) {
    VFile file;
    if (!p.fdtable.get(fd, file))
        return Err.BADF;
    if (!file.lseek)
        return Err.PERM;
    return file.lseek(file.dev, p, off, whence);
}

struct Iovec {
    uintptr base;
    usize len;
}

ssize sys_read(Proc* p, int fd, uintptr buf, usize size) {
    VFile file;
    if (!p.fdtable.get(fd, file)) {
        return Err.BADF;
    }
    if (file.read == null) {
        return Err.PERM;
    }
    if (!checkptr(p, buf, size)) {
        return Err.FAULT;
    }
    ssize i = 0;
    while (size > 0) {
        VmMap map = vm_lookup(p.pt, buf + i);
        if ((map.perm & Perm.WRITE) == 0) {
            return Err.FAULT;
        }
        ssize n = file.read(file.dev, p, cast(ubyte*) map.ka, min(size, map.size));
        i += n;
        if (n < min(size, map.size)) {
            break;
        }
        size -= n;
    }
    return i;
}

ssize sys_writev(Proc* p, ulong a0, ulong a1, ulong a2) {
    int fd = cast(int) a0;
    uintptr iovp = a1;
    usize iovcnt = a2;
    if (!checkptr(p, iovp, iovcnt * Iovec.sizeof)) {
        return Err.FAULT;
    }
    Iovec[] iov = (cast(Iovec*) iovp)[0 .. iovcnt];
    ssize total = 0;
    // TODO: additional checks on iov
    for (int i = 0; i < iov.length; i++) {
        ssize n = sys_write(p, fd, iov[i].base, iov[i].len);
        if (n < 0) {
            return n;
        }
        total += n;
    }
    return total;
}

ssize sys_write(Proc* p, int fd, uintptr buf, usize size) {
    VFile file;
    if (!p.fdtable.get(fd, file)) {
        return Err.BADF;
    }
    if (file.write == null) {
        return Err.PERM;
    }
    if (!checkptr(p, buf, size)) {
        return Err.FAULT;
    }
    ssize i = 0;
    while (size > 0) {
        VmMap map = vm_lookup(p.pt, buf + i);
        if ((map.perm & Perm.READ) == 0) {
            return Err.FAULT;
        }
        ssize n = file.write(file.dev, p, cast(ubyte*) map.ka, min(size, map.size));
        i += n;
        if (n < min(size, map.size)) {
            break;
        }
        size -= n;
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

    addstring(buf.sysname, "Linux");
    buf.nodename = null;
    addstring(buf.release, "6.0.0-revisor");
    buf.version_ = null;
    buf.machine = null;
    return 0;
}

uintptr sys_mmap(Proc* p, uintptr addr, usize length, int prot, int flags, int fd, long offset) {
    assert(fd == -1);
    assert(offset == 0);

    addr = truncpg(addr);
    length = ceilpg(length);

    if (addr == 0) {
        if (!p.map_vma_any(length, prot, flags, addr)) {
            return Err.NOMEM;
        }
    } else {
        if (!p.map_vma(addr, length, prot, flags)) {
            return Err.NOMEM;
        }
    }

    return addr;
}

int sys_munmap(Proc* p, uintptr addr, usize length) {
    addr = truncpg(addr);
    length = ceilpg(length);

    if (!p.unmap_vma(addr, length)) {
        return Err.NOMEM;
    }

    return 0;
}
