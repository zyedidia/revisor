#include <stdint.h>
#include <stdio.h>

#include "arch/init.h"

uint8_t* hypcall_dev = (uint8_t*) 0x4000;
size_t memory_size;

void kinit(size_t memsz) {
    memory_size = memsz;

    arch_init();
}
