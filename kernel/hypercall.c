#include <stdlib.h>
#include <sys/times.h>
#include <sys/stat.h>

#include "hypercall.h"

void* sbrk(int incr) {
    return NULL;
}

int close(int file) {
    return hypercall_1(HYP_CLOSE, file);
}

int open(const char* name, int flags, int mode) {
    return hypercall_3(HYP_OPEN, (uintptr_t) name, flags, mode);
}

int fstat(int file, struct stat* st) {
    return -1;
}

int isatty(int file) {
    return 1;
}

int lseek(int file, int ptr, int dir) {
    return 0;
}

void _exit(int status) {
    hypercall_0(HYP_EXIT);
    while (1) {}
}

void kill(int pid, int sig) {
    return;
}

int getpid(void) {
    return 0;
}

int write(int file, char* ptr, int len) {
    return hypercall_3(HYP_WRITE, file, (uintptr_t) ptr, len);
}

int read(int file, char* ptr, int len) {
    return hypercall_3(HYP_READ, file, (uintptr_t) ptr, len);
}

int unlink(char* name) {
    return -1;
}

clock_t times(struct tms* buf) {
    return -1;
}
