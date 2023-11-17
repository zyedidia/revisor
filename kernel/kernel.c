#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "hypercall.h"
#include "x86-64.h"

char _tls_start;
unsigned _bss_start, _bss_end;

void init_bss() {
    unsigned* bss = &_bss_start;
    unsigned* bss_end = &_bss_end;
    while (bss < bss_end) {
        *bss++ = 0;
    }
}

void kernel_main() {
    init_bss();

    wrmsr(MSR_IA32_FS_BASE, (uint64_t) &_tls_start);

    printf("kernel booted...\n");

    puts("reading 32 bytes from hypercall.go");
    FILE* fp = fopen("hypercall.go", "r");
    char buf[32];
    /* fread(buf, 10, 1, fp); */
    memset(buf, 0, 32);
    /* buf[31] = 0; */
    /* puts(buf); */
    /* fclose(fp); */
}
