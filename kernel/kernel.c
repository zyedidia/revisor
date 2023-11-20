#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "hypercall.h"
#include "x86-64.h"
#include "kernel.h"

void exception_return(x86_64_registers* regs) __attribute__((noreturn));

void exception(x86_64_registers* reg) {
    printf("exception %p, %lx\n", reg, reg->reg_rsp);
    printf("returning to %lx %lx %lx\n", reg->reg_rip, reg->reg_intno, reg->reg_err);

    exception_return(reg);
}

void kmain() {
    printf("entered kmain at %p\n", &kmain);

    asm volatile ("int $0x80");

    printf("done\n");

    /* int* x = NULL; */
    /* *x = 10; */
}

void filetest() {
    puts("reading 32 bytes from hypercall.go");
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

void run(struct proc* p) {
    assert(p->p_state == P_RUNNABLE);

    set_pagetable(p->p_pagetable);
    exception_return(&p->p_registers);
}
