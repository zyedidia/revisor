#include "hyper.h"
#include "arch/hypercall.h"

uint8_t* brkp;
extern uint8_t _end;

void sbrk_init() {
    brkp = &_end;
}

void* sbrk(int incr) {
    uint8_t* prev_brkp = brkp;
    brkp += incr;
    return (void*) prev_brkp;
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
