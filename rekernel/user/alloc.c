#include <stdio.h>
#include <stdlib.h>
int main() {
    // small allocations
    for (int i = 0; i < 10; i++) {
        int* p = malloc(1024);
        printf("allocated: %p\n", p);
    }

    // large allocations
    for (int i = 0; i < 10; i++) {
        int* p = malloc(1024 * 1024);
        printf("allocated: %p\n", p);
    }
    return 0;
}
