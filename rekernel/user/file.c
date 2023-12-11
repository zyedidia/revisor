#include <stdio.h>
#include <stdlib.h>
int main() {
    FILE* f = fopen("main.d", "r");
    if (!f) {
        printf("%s does not exist\n", "file.c");
        return 1;
    }
    char buf[1024];
    int n = fread(buf, 1, 1024, f);
    fwrite(buf, 1, n, stdout);
    return 0;
}
