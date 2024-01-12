module timer;

import arch = arch.timer;

enum time_slice = 10000;

void timer_setup() {
    arch.timer_setup();
}

// Delay until `t` ticks have expired from `tfn`.
private void delay(alias tfn)(ulong t) {
    ulong rb = tfn();
    while (true) {
        ulong ra = tfn();
        if ((ra - rb) >= t) {
            break;
        }
    }
}

// Delay for `cyc` cycles.
void timer_delay_cycles(ulong cyc) {
    delay!(arch.timer_cycles)(cyc);
}

// Delay for `us` microseconds.
void timer_delay_us(ulong us) {
    delay!(arch.timer_time)(us * arch.timer_freq() / 1_000_000);
}

// Delay for `ms` milliseconds.
void timer_delay_ms(ulong ms) {
    timer_delay_us(ms * 1000);
}

ulong timer_cycles() {
    return arch.timer_cycles();
}

ulong timer_time() {
    return arch.timer_time();
}

ulong timer_us_since(ulong prev_time) {
    return (arch.timer_time - prev_time) * 1_000_000 / arch.timer_freq();
}

void timer_intr(ulong us) {
    arch.timer_intr(us);
}
