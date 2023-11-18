#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "hypercall.h"
#include "x86-64.h"

char _tls_start;
unsigned _bss_start, _bss_end;

void kernel_init() {
    unsigned* bss = &_bss_start;
    unsigned* bss_end = &_bss_end;
    while (bss < bss_end) {
        *bss++ = 0;
    }

    wrmsr(MSR_IA32_FS_BASE, (uint64_t) &_tls_start);
}

void kernel_main() {
    printf("kernel booted...\n");

    /* puts("reading 32 bytes from hypercall.go"); */
    FILE* fp = fopen("hypercall.go", "r");
    if (fp == NULL) {
        printf("FILE DOES NOT EXIST DUMBO\n");
        return;
    }
    char buf[1024];
    fread(buf, 1, 10, fp);
    buf[31] = 0;
    puts(buf);
    fclose(fp);
}
