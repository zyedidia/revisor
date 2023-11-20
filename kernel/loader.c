#include <elf.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>

#include "kernel.h"

#define ALIGN (PAGESIZE - 1)

static inline uintptr_t truncpg(uintptr_t addr) {
    return addr & ~ALIGN;
}

static inline uintptr_t ceilpg(uintptr_t addr) {
    return (addr + ALIGN) & ~ALIGN;
}

static int check_ehdr(Elf64_Ehdr* ehdr) {
    unsigned char* e_ident = ehdr->e_ident;
    return !(e_ident[EI_MAG0] != ELFMAG0 || e_ident[EI_MAG1] != ELFMAG1 ||
             e_ident[EI_MAG2] != ELFMAG2 || e_ident[EI_MAG3] != ELFMAG3 ||
             e_ident[EI_CLASS] != ELFCLASS64 ||
             e_ident[EI_VERSION] != EV_CURRENT || ehdr->e_type != ET_EXEC);
}

int program_load(struct proc* p, int fd) {
    Elf64_Ehdr ehdr;
    if (read(fd, &ehdr, sizeof(ehdr)) != sizeof(ehdr)) {
        printf("can't read ELF header\n");
        return 1;
    }
    if (!check_ehdr(&ehdr)) {
        printf("bad ELF header\n");
        return 1;
    }

    ssize_t sz = ehdr.e_phnum * sizeof(Elf64_Phdr);
    Elf64_Phdr* phdr = malloc(sz);
    if (lseek(fd, ehdr.e_phoff, SEEK_SET) < 0) {
        printf("seek to program header failed\n");
        return 1;
    }
    if (read(fd, phdr, sz) != sz) {
        printf("read program header failed\n");
        return 1;
    }

    for (Elf64_Phdr* iter = phdr; iter < &phdr[ehdr.e_phnum]; iter++) {
        if (iter->p_type != PT_LOAD)
            continue;
        uintptr_t start = truncpg(iter->p_vaddr);
        uintptr_t end = ceilpg(iter->p_vaddr + iter->p_memsz);

        void* segment = aligned_alloc(PAGESIZE, end - start);
        assert(segment);

        if (lseek(fd, iter->p_offset, SEEK_SET) < 0)
            goto err;
        if (read(fd, segment, iter->p_filesz) != (ssize_t) iter->p_filesz)
            goto err;
        memset(segment + iter->p_filesz, 0, iter->p_memsz - iter->p_filesz);

        if (virtual_memory_map(p->p_pagetable, start, ka2pa((uintptr_t) segment), end - start, PTE_P | PTE_W | PTE_U, true) < 0)
            goto err;
    }

    p->p_registers.reg_rip = ehdr.e_entry;

    return 0;

err:
    // TODO: undo
    return -1;
}
