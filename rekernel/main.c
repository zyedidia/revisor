#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

void kmain() {
    printf("arrived in kmain at %p\n", &kmain);

    int* p = malloc(10);
    printf("malloc: %p\n", p);
}
