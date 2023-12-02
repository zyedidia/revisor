#include <stdint.h>
#include <stdio.h>

#include "arch/init.h"

uint8_t* hypcall_dev;

void sbrk_init();

void kinit(uint8_t* hypdev) {
    hypcall_dev = hypdev;

    arch_init();
}
