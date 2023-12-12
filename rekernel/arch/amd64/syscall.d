module arch.amd64.syscall;

import arch.amd64.sys;

import syscall;
import proc;

enum Sys {
    FCNTL = 72,
    IOCTL = 16,
    OPENAT = 257,
    CLOSE = 3,
    LSEEK = 8,
    READ = 0,
    WRITE = 1,
    READV = 19,
    WRITEV = 20,
    READLINKAT = 267,
    NEWFSTATAT = 262,
    EXIT = 60,
    EXIT_GROUP = 231,
    SET_TID_ADDRESS = 218,
    SET_ROBUST_LIST = 273,
    CLOCK_GETTIME = 228,
    TGKILL = 234,
    RT_SIGACTION = 13,
    RT_SIGPROCMASK = 14,
    UNAME = 63,
    GETPID = 39,
    GETUID = 102,
    GETEUID = 107,
    GETGID = 104,
    GETEGID = 108,
    GETTID = 186,
    SYSINFO = 99,
    BRK = 12,
    MUNMAP = 11,
    MREMAP = 25,
    MMAP = 9,
    MPROTECT = 10,
    PRLIMIT64 = 302,
    GETRANDOM = 318,
    RSEQ = 334,
    ARCH_PRCTL = 158,
}

enum {
    ARCH_SET_FS = 0x1002,
}

int sys_arch_prctl(Proc* p, int code, ulong addr) {
    switch (code) {
    case ARCH_SET_FS:
        if (!checkptr(p, addr, 1)) {
            return Err.FAULT;
        }
        // p.trapframe.regs.fs = SEGSEL_APP_DATA;
        wr_msr(MSR_IA32_FS_BASE, addr);
        return 0;
    default:
        return Err.INVAL;
    }
}
