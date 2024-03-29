module syscall;

import arch.vm;
import arch.sys;
import arch.syscall;
import arch.types;

import core.alloc;
import core.lib;
import core.math;

import proc;
import trap;
import vm;
import schedule;
import file;
import config;

enum Err {
    AGAIN       = -11,       // Try again
    BADF        = -9,        // Bad file number
    CHILD       = -10,       // No child processes
    FAULT       = -14,       // Bad address
    FBIG        = -27,       // File too large
    INTR        = -4,        // Interrupted system call
    INVAL       = -22,       // Invalid argument
    IO          = -5,        // I/O error
    MFILE       = -24,       // Too many open files
    NAMETOOLONG = -36,       // File name too long
    NFILE       = -23,       // File table overflow
    NOENT       = -2,        // No such file or directory
    NOEXEC      = -8,        // Exec format error
    NOMEM       = -12,       // Out of memory
    NOSPC       = -28,       // No space left on device
    NOSYS       = -38,       // Invalid system call number
    NXIO        = -6,        // No such device or address
    PERM        = -1,        // Operation not permitted
    PIPE        = -32,       // Broken pipe
    RANGE       = -34,       // Out of range
    SPIPE       = -29,       // Illegal seek
    SRCH        = -3,        // No such process
    TXTBSY      = -26,       // Text file busy
    TOOBIG      = -7,        // Argument list too long
}

bool checkptr(Proc* p, uintptr ptr, usize size) {
    // TODO: improve
    if (ptr >= USER_END) {
        return false;
    }
    return true;
}

bool checkstr(Proc* p, uintptr str) {
    // TODO: improve
    return checkptr(p, str, 1);
}

uintptr syscall_handler(Proc* p, ulong sysno, ulong a0, ulong a1, ulong a2, ulong a3, ulong a4, ulong a5) {
    uintptr ret;

    switch (sysno) {
    case Sys.GETPID:
        ret = sys_getpid(p);
        break;
    case Sys.GETTID:
        ret = 42;
        break;
    case Sys.BRK:
        ret = sys_brk(p, a0);
        break;
    case Sys.LSEEK:
        ret = sys_lseek(p, cast(int) a0, a1, cast(int) a2);
        break;
    case Sys.GETDENTS64:
        ret = sys_getdents64(p, cast(int) a0, a1, a2);
        break;
    case Sys.READ:
        ret = sys_read(p, cast(int) a0, a1, a2);
        break;
    case Sys.PREAD64:
        ret = sys_pread64(p, cast(int) a0, a1, a2, a3);
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
    case Sys.FSTAT:
        ret = sys_fstatat(p, cast(int) a0, 0, a1, AT_EMPTY_PATH);
        break;
    case Sys.NEWFSTATAT:
        ret = sys_fstatat(p, cast(int) a0, a1, a2, cast(int) a3);
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
    case Sys.CLOCK_GETTIME:
        ret = sys_clock_gettime(p, a0, a1);
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
    case Sys.CLONE:
        ret = sys_clone(p);
        break;
    case Sys.WAIT4:
        ret = sys_wait4(p, cast(int) a0, a1);
        break;
    case Sys.SET_TID_ADDRESS, Sys.SET_ROBUST_LIST, Sys.IOCTL, Sys.PRLIMIT64, Sys.FCNTL, Sys.FUTEX:
        // ignored
        ret = 0;
        break;
    version (amd64) {
    // amd64-only syscalls
    case Sys.ARCH_PRCTL:
        ret = sys_arch_prctl(p, cast(int) a0, a1);
        break;
    }
    default:
        eprintf("[warning]: unknown syscall: %ld\n", sysno);
        return Err.NOSYS;
    }

    if (trace) {
        eprintf("strace: %s() = 0x%lx\n", syscall_names[sysno].ptr == null ? "(unknown)" : syscall_names[sysno].ptr, ret);
    }

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

ssize sys_pread64(Proc* p, int fd, uintptr buf, usize size, ssize offset) {
    VFile file;
    if (!p.fdtable.get(fd, file)) {
        return Err.BADF;
    }
    if (file.read == null || file.lseek == null) {
        return Err.PERM;
    }
    if (!checkptr(p, buf, size)) {
        return Err.FAULT;
    }
    ssize orig = file.lseek(file.dev, p, 0, SEEK_CUR);
    file.lseek(file.dev, p, offset, SEEK_SET);
    scope(exit) file.lseek(file.dev, p, orig, SEEK_SET);
    ssize n = file.read(file.dev, p, cast(ubyte*) buf, size);
    return n;
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
    if (!pte || !pte.valid) {
        usize diff = ceilpg(addr) - oldbrk;
        ubyte[] data = kzalloc(diff);
        if (!data)
            return Err.NOMEM;
        if (!p.pt.map_region(oldbrk, ka2pa(data.ptr), data.length, Perm.READ | Perm.WRITE | Perm.USER)) {
            kfree(data);
            return Err.NOMEM;
        }
    } else if (pte && (pte.perm & Perm.USER) == 0) {
        return Err.FAULT;
    }
    return p.brk;
}

noreturn sys_exit(Proc* p, int status) {
    eprintf("%d: exited\n", p.pid);

    // TODO: reparent

    if (p.parent && p.parent.state == Proc.State.BLOCKED && p.parent.wq == &waitq) {
        waitq.wake(p.parent);
    }

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
    buf.nodename[0] = 0;
    addstring(buf.release, "6.0.0-revisor");
    buf.version_[0] = 0;
    buf.machine[0] = 0;
    return 0;
}

uintptr sys_mmap(Proc* p, uintptr addr, usize length, int prot, int flags, int fd, long offset) {
    addr = truncpg(addr);

    ubyte[] ka;
    if (addr == 0) {
        if (!p.map_vma_any(length, prot, flags, fd, offset, addr, ka)) {
            return Err.NOMEM;
        }
    } else {
        if (!p.map_vma(addr, length, prot, flags, fd, offset, ka)) {
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

enum {
    CLOCK_REALTIME  = 0,
    CLOCK_MONOTONIC = 1,
}

int sys_clock_gettime(Proc* p, ulong clockid, uintptr tp) {
    if (!checkptr(p, tp, TimeSpec.sizeof)) {
        return Err.FAULT;
    }
    if (clockid != CLOCK_REALTIME && clockid != CLOCK_MONOTONIC) {
        return Err.INVAL;
    }
    TimeSpec* t = cast(TimeSpec*) tp;
    ulong sec, nsec;
    int ret = time(&sec, &nsec);
    t.sec = sec;
    t.nsec = nsec;
    return ret;
}

int sys_fstatat(Proc* p, int dirfd, uintptr pathname, uintptr statbuf, int flags) {
    if ((flags & AT_EMPTY_PATH) == 0) {
        if (!checkstr(p, pathname))
            return Err.FAULT;
        // TODO: only supports AT_EMPTY_PATH
        return Err.INVAL;
    }
    if (!checkptr(p, statbuf, statbuf.sizeof))
        return Err.FAULT;
    VFile file;
    if (!p.fdtable.get(dirfd, file))
        return Err.BADF;
    if (!file.stat)
        return Err.BADF;
    Stat* stat = cast(Stat*) statbuf;
    StatHyper stath;
    if (file.stat(file.dev, p, &stath) < 0)
        return Err.INVAL;
    stat.st_mode = stath.mode;
    stat.st_size = stath.size;
    stat.st_uid = stath.uid;
    stat.st_gid = stath.gid;
    stat.st_dev = stath.dev;
    stat.st_rdev = stath.rdev;
    stat.st_ino = stath.ino;
    stat.st_mtim = TimeSpec(stath.mtim_sec, stath.mtim_nsec);
    return 0;
}

int sys_wait4(Proc* p, int pid, uintptr wstatus) {
    if (pid != -1 || wstatus != 0)
        return Err.INVAL;
    if (p.children.length == 0)
        return Err.CHILD;

    while (1) {
        Proc* zombie = exitq.front;
        while (zombie) {
            if (zombie.parent == p) {
                int zpid = zombie.pid;
                for (usize i = 0; i < p.children.length; i++) {
                    if (p.children[i] == zombie) {
                        p.children.unordered_remove(i);
                        break;
                    }
                }
                exitq.remove(zombie);
                // TODO: free the zombie
                return zpid;
            }
            zombie = zombie.next;
        }

        p.block(&waitq, Proc.State.BLOCKED);
    }
}

int sys_clone(Proc* p) {
    return sys_fork(p);
}

int sys_fork(Proc* p) {
    Proc* child = Proc.make_from_parent(p);
    if (!child) {
        return Err.NOMEM;
    }
    child.trapframe.regs.ret = 0;
    p.children.append(child);

    int pid = child.pid;
    runq.push_front(child);
    return pid;
}

ssize sys_getdents64(Proc* p, int fd, uintptr dirp, usize count) {
    VFile file;
    if (!p.fdtable.get(fd, file)) {
        return Err.BADF;
    }
    if (file.getdents64 == null) {
        return Err.PERM;
    }
    if (!checkptr(p, dirp, count)) {
        return Err.FAULT;
    }
    ubyte[] kdir = kalloc(count);
    ssize n = file.getdents64(file.dev, p, kdir.ptr, count);
    memcpy(cast(void*) dirp, kdir.ptr, count);
    kfree(kdir);
    return n;
}
