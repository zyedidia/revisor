module arch.amd64.types;

struct TimeSpec {
    ulong sec;
    ulong nsec;
}

alias dev_t = ulong;
alias ino_t = ulong;
alias nlink_t = ulong;
alias mode_t = uint;
alias uid_t = uint;
alias gid_t = uint;
alias off_t = ulong;
alias blksize_t = ulong;
alias blkcnt_t = ulong;

struct Stat {
    dev_t st_dev;
    ino_t st_ino;
    nlink_t st_nlink;

    mode_t st_mode;
    uid_t st_uid;
    gid_t st_gid;
    uint __pad0;
    dev_t st_rdev;
    off_t st_size;
    blksize_t st_blksize;
    blkcnt_t st_blocks;

    TimeSpec st_atim;
    TimeSpec st_mtim;
    TimeSpec st_ctim;
    long[3] __unused;
}
