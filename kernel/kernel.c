#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>

#include "hypercall.h"
#include "x86-64.h"

char _tls_start;

void kernel_main() {
    wrmsr(MSR_IA32_FS_BASE, (uint64_t) &_tls_start);

    printf("kernel booted...\n");

    puts("reading 32 bytes from hypercall.go");
    int fd = open("../hypercall.go", O_RDONLY);
    char buf[32];
    read(fd, buf, 31);
    buf[31] = 0;
    puts(buf);
    close(fd);
}
