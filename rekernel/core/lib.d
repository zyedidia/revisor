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

noreturn exit(int status);

enum {
    SEEK_SET = 0,
    SEEK_CUR = 1,
    SEEK_END = 2,

    O_RDONLY = 0,
}
