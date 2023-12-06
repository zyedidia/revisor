module core.math;

T min(T, U)(T a, U b) if (is(T == U) && is(typeof(a < b))) {
    return b < a ? b : a;
}

T max(T, U)(T a, U b) if (is(T == U) && is(typeof(a < b))) {
    return a < b ? b : a;
}

private enum ALIGN = (PAGESIZE - 1);

uintptr truncpg(uintptr addr) {
    return addr & ~ALIGN;
}

uintptr ceilpg(uintptr addr) {
    return (addr + ALIGN) & ~ALIGN;
}
