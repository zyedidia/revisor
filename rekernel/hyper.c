#include <string.h>
#include <errno.h>

#include "hyper.h"
#include "arch/hypercall.h"

extern uint8_t _end;
uint8_t* brkp = &_end;

void* sbrk(size_t incr) {
    if (incr < 0) {
        if ((size_t) (brkp - &_end) < (size_t) (-incr)) {
            errno = ENOMEM;
            return (void *) -1;
        }
    }
    void *ret = brkp;
    brkp += incr;
    return ret;
}

int open(const char* name, int flags, int mode) {
    return hypercall3((uintptr_t) name, flags, mode, HYP_OPEN);
}

int close(int file) {
    return hypercall1(file, HYP_CLOSE);
}

int lseek(int file, uint64_t off, int whence) {
    return hypercall3(file, off, whence, HYP_LSEEK);
}

int lseek64(int file, uint64_t off, int whence) {
    return hypercall3(file, off, whence, HYP_LSEEK);
}

int write(int file, char* ptr, int len) {
    return hypercall3(file, (uintptr_t) ptr, len, HYP_WRITE);
}

int read(int file, char* ptr, int len) {
    return hypercall3(file, (uintptr_t) ptr, len, HYP_READ);
}

void exit(int status) {
    hypercall1(status, HYP_EXIT);
    while (1) {}
}

int isatty(int file) {
    return 1;
}

int fstat(int file, void* st) {
    return -1;
}
