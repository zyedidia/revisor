module arch.arm64.types;

struct TimeSpec {
    ulong sec;
    ulong nsec;
}

alias dev_t = ulong;
alias ino_t = ulong;
alias nlink_t = uint;
alias mode_t = uint;
alias uid_t = uint;
alias gid_t = uint;
alias off_t = ulong;
alias blksize_t = uint;
alias blkcnt_t = ulong;

struct Stat {
    dev_t st_dev;
	ino_t st_ino;
	mode_t st_mode;
	nlink_t st_nlink;
	uid_t st_uid;
	gid_t st_gid;
	dev_t st_rdev;
	ulong __pad;
	off_t st_size;
	blksize_t st_blksize;
	int __pad2;
	blkcnt_t st_blocks;
	TimeSpec st_atim;
	TimeSpec st_mtim;
	TimeSpec st_ctim;
	uint[2] __unused;
}
