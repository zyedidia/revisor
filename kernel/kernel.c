#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "hypercall.h"
#include "x86-64.h"

extern uint8_t* brk;
extern uint8_t _end;

void kinit() {
    brk = &_end;
    void* tls = malloc(4096);
    wrmsr(MSR_IA32_GS_BASE, (uint64_t) tls);
}

void kmain() {
    printf("entered kmain at %p\n", &kmain);

    /* puts("reading 32 bytes from hypercall.go"); */
    /* FILE* fp = fopen("hypercall.go", "r"); */
    /* if (fp == NULL) { */
    /*     printf("FILE DOES NOT EXIST DUMBO\n"); */
    /*     return; */
    /* } */
    /* char buf[1024]; */
    /* fread(buf, 1, 10, fp); */
    /* buf[31] = 0; */
    /* puts(buf); */
    /* fclose(fp); */
}
