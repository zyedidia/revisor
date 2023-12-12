module core.lib;

extern (C):

void* memcpy(void* dst, const(void)* src, usize n);
void* memmove(void* dst, const(void)* src, usize n);
void* memset(void* v, int c, usize n);

void* malloc(usize size);
void* aligned_alloc(usize alignment, usize size);
void free(void* ptr);

usize strlen(const(char)* s);
usize strnlen(const(char*) s, usize len);

int open(const char* name, int flags, int mode);
ssize read(int fd, void* buf, usize count);
ssize write(int fd, void* buf, usize count);
ssize lseek(int fd, ssize offset, int whence);
int close(int fd);

void* fdopen(int fd, const(char)* mode);
usize fread(const void* ptr, usize size, usize nmemb, void* stream);
usize fwrite(const void* ptr, usize size, usize nmemb, void* stream);
int fseek(void* stream, ssize off, uint whence);
int fclose(void* stream);
int fflush(void* stream);
int fileno(void* stream);

int time(ulong* sec, ulong* nsec);

struct StatHyper {
    usize size;
    uint mode;
    ulong mtim_sec;
    ulong mtim_nsec;
    ulong ino;
    ulong dev;
    uint uid;
    uint gid;
    ulong rdev;
}

int fstat(int file, StatHyper* st);

extern (C) __gshared {
    extern void* stdout;
    extern void* stderr;
    extern void* stdin;
    extern int errno;
}

noreturn exit(int status);

enum {
    SEEK_SET = 0,
    SEEK_CUR = 1,
    SEEK_END = 2,

    O_RDONLY = 0,
    O_WRONLY = 1,
    O_RDWR   = 2,
    O_APPEND = 0x0400,
    O_TRUNC  = 0x0200,
    O_CREAT  = 0x0040,
}
