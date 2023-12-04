#include <stdio.h>

#include "arch/arm64/sys.h"
#include "arch/arm64/regs.h"

#include "bits.h"

void kernel_exception(struct regs* regs) {
    (void) regs;
    unsigned long exc_class = bits_get(rd_sys(esr_el1), 31, 26);
    printf("kernel exception: esr: %lx, elr: %lx\n", exc_class, rd_sys(elr_el1));
}

void kernel_interrupt(struct regs* regs) {
    (void) regs;
    printf("kernel interrupt\n");
}

void user_exception() {
    unsigned long exc_class = bits_get(rd_sys(esr_el1), 31, 26);
    printf("kernel exception: esr: %lx, elr: %lx\n", exc_class, rd_sys(elr_el1));
}

void user_interrupt() {
    printf("kernel interrupt\n");
}
