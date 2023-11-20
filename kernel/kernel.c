#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

#include "hypercall.h"
#include "x86-64.h"
#include "kernel.h"

void exception_return(x86_64_registers* regs) __attribute__((noreturn));

struct proc process;

void exception(x86_64_registers* reg) {
    printf("exception from %lx, int: %lx, err: %lx\n", reg->reg_rip, reg->reg_intno, reg->reg_err);

    exit(0);

    exception_return(reg);
}

void proc_setup(struct proc* p, const char* elfname);
void run(struct proc* p);

void kmain() {
    printf("entered kmain at %p\n", &kmain);

    proc_setup(&process, "user/test.elf");
    run(&process);
}

void proc_setup(struct proc* p, const char* elfname) {
    x86_64_pagetable* kernel_pagetable = (x86_64_pagetable*) pa2ka(rcr3());

    proc_init(p);
    p->p_pagetable = new_upt(kernel_pagetable);
    assert(p->p_pagetable);
    int fd = open(elfname, O_RDONLY);
    assert(fd >= 0);
    int r = program_load(p, fd);
    assert(r >= 0);
    close(fd);

    p->p_registers.reg_rsp = LOWMEM_END;
    uintptr_t stack_va = p->p_registers.reg_rsp - PAGESIZE;
    uintptr_t stack_pa = ka2pa((uintptr_t) aligned_alloc(PAGESIZE, PAGESIZE));
    assert(virtual_memory_map(p->p_pagetable, stack_va, stack_pa, PAGESIZE, PTE_P | PTE_W | PTE_U, true) >= 0);

    p->p_state = P_RUNNABLE;
}

void run(struct proc* p) {
    assert(p->p_state == P_RUNNABLE);

    set_pagetable(p->p_pagetable);

    exception_return(&p->p_registers);
}
