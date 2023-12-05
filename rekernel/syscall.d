module syscall;

import arch.vm;
import arch.sys;

import core.lib;
import core.math;

import proc;
import trap;
import vm;

enum Sys {
    WRITE = 64,
    GETPID = 172,
    EXIT = 93,
    EXIT_GROUP = 94,
}

enum Err {
    PERM = -1,
    BADF = -9,
}

uintptr syscall_handler(Proc* p, ulong sysno, ulong a0, ulong a1, ulong a2, ulong a3, ulong a4, ulong a5) {
    uintptr ret;

    switch (sysno) {
    case Sys.GETPID:
        ret = sys_getpid(p);
        break;
    case Sys.WRITE:
        ret = sys_write(p, cast(int) a0, cast(void*) a1, a2);
        break;
    case Sys.EXIT, Sys.EXIT_GROUP:
        sys_exit(p, cast(int) a0);
    default:
        printf("unknown syscall: %ld\n", sysno);
        unhandled(p);
    }

    return ret;
}

int sys_getpid(Proc* p) {
    return p.pid;
}

ssize sys_write(Proc* p, int fd, uintptr buf, usize size) {
    if (fd != 1) {
        return Err.BADF;
    }
    ssize i = 0;
    while (size) {
        VmMap map = vm_lookup(p.pt, buf + i);
        if ((map.perm & Perm.READ) == 0) {
            return Err.PERM;
        }
        ssize n = write(fd, cast(void*) map.ka, min(size, map.size));
        size -= n;
        i += n;
    }
    return i;
}

noreturn sys_exit(Proc* p, int status) {
    printf("%d: exited\n", p.pid);
    exit(1);
}
