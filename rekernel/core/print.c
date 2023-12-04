#include <stdio.h>
#include <string.h>

int errstr(char* s, size_t size) {
    return fwrite(s, 1, size, stderr);
}
