module sys;

pragma(inline, true)
usize kb(usize i) {
    return i * 1024;
}

pragma(inline, true)
usize mb(usize i) {
    return i * 1024 * 1024;
}

pragma(inline, true)
usize gb(usize i) {
    return i * 1024 * 1024 * 1024;
}
