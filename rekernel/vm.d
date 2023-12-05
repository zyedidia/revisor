module vm;

enum Perm {
    READ  = 1 << 0,
    WRITE = 1 << 1,
    EXEC  = 1 << 2,
    USER  = 1 << 3,
    COW   = 1 << 4,
}
