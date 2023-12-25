module arch.amd64.syscall;

import arch.amd64.sys;

import syscall;
import proc;

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
    FSTAT = 5,
    PREAD64 = 17,
    WAIT4 = 61,
    CLONE = 56,
    FORK = 57,
    VFORK = 58,
    EXECVE = 59,
    GETDENTS64 = 217,
}

immutable string[] syscall_names = [
    Sys.FCNTL: "fcntl",
    Sys.IOCTL: "ioctl",
    Sys.OPENAT: "openat",
    Sys.CLOSE: "close",
    Sys.LSEEK: "lseek",
    Sys.READ: "read",
    Sys.WRITE: "write",
    Sys.READV: "readv",
    Sys.WRITEV: "writev",
    Sys.READLINKAT: "readlinkat",
    Sys.NEWFSTATAT: "newfstatat",
    Sys.EXIT: "exit",
    Sys.EXIT_GROUP: "exit_group",
    Sys.SET_TID_ADDRESS: "set_tid_address",
    Sys.SET_ROBUST_LIST: "set_robust_list",
    Sys.CLOCK_GETTIME: "clock_gettime",
    Sys.TGKILL: "tgkill",
    Sys.RT_SIGACTION: "rt_sigaction",
    Sys.RT_SIGPROCMASK: "rt_sigprocmask",
    Sys.UNAME: "uname",
    Sys.GETPID: "getpid",
    Sys.GETUID: "getuid",
    Sys.GETEUID: "geteuid",
    Sys.GETGID: "getgid",
    Sys.GETEGID: "getegid",
    Sys.GETTID: "gettid",
    Sys.SYSINFO: "sysinfo",
    Sys.BRK: "brk",
    Sys.MUNMAP: "munmap",
    Sys.MREMAP: "mremap",
    Sys.MMAP: "mmap",
    Sys.MPROTECT: "mprotect",
    Sys.PRLIMIT64: "prlimit64",
    Sys.GETRANDOM: "getrandom",
    Sys.RSEQ: "rseq",
    Sys.ARCH_PRCTL: "arch_prctl",
    Sys.FSTAT: "fstat",
    Sys.PREAD64: "pread64",
    Sys.WAIT4: "wait4",
    Sys.CLONE: "clone",
    Sys.FORK: "fork",
    Sys.VFORK: "vfork",
    Sys.EXECVE: "execve",
    Sys.GETDENTS64: "getdents64",
];
