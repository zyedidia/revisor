module core.bits;

import core.trait : isint;

pragma(inline, true)
T mask(T)(uint nbits) if (isint!T) {
    if (nbits == T.sizeof * 8) {
        return cast(T) ~(cast(T) 0);
    }
    return cast(T) (((cast(T) 1) << nbits) - 1);
}

pragma(inline, true)
T get(T)(T x, uint ub, uint lb) if (isint!T) {
    return cast(T) ((x >> lb) & mask!T(ub - lb + 1));
}

pragma(inline, true)
T get(T)(T x, uint bit) if (isint!T) {
    return cast(T) ((x >> bit) & (cast(T) 1));
}

pragma(inline, true)
T clear(T)(T x, uint hi, uint lo) if (isint!T) {
    T m = mask!T(hi - lo + 1);
    return cast(T) (x & ~(m << lo));
}

pragma(inline, true)
T clear(T)(T x, uint bit) if (isint!T) {
    return cast(T) (x & ~((cast(T) 1) << bit));
}

pragma(inline, true)
T set(T)(T x, uint bit) if (isint!T) {
    return cast(T) (x | ((cast(T) 1) << bit));
}

pragma(inline, true)
T write(T)(T x, uint bit, uint val) if (isint!T) {
    x = clear(x, bit);
    return cast(T) (x | (val << bit));
}

pragma(inline, true)
T write(T)(T x, uint hi, uint lo, T val) if (isint!T) {
    return cast(T) (clear(x, hi, lo) | (val << lo));
}

pragma(inline, true)
T remap(T)(T i, uint from, uint to) if (isint!T) {
    return cast(T) (get(i, from) << to);
}

pragma(inline, true)
T remap(T)(T i, uint from_ub, uint from_lb, uint to_ub, uint to_lb) {
    return cast(T) (get(i, from_ub, from_lb) << to_lb);
}

pragma(inline, true)
T sext(T, UT)(UT x, uint width) {
    ulong n = (T.sizeof * 8 - 1) - (width-1);
    return (cast(T)(x << n)) >> n;
}
