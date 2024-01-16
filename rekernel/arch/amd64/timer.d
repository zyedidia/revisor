module arch.amd64.timer;

void timer_setup() {}

ulong timer_freq() {
    return 0;
}

ulong timer_time() {
    return 0;
}

ulong timer_cycles() {
    return 0;
}

void timer_intr(ulong us) {}
