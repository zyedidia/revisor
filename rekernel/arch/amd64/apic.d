module arch.amd64.apic;

import core.volatile;

enum {
    LAPIC_REG_ID = 0x02,
    LAPIC_REG_TPR = 0x08,
    LAPIC_REG_SVR = 0x0F,
    LAPIC_REG_ISR = 0x10,
    LAPIC_REG_TMR = 0x18,
    LAPIC_REG_IRR = 0x20,
    LAPIC_REG_ESR = 0x28,
    LAPIC_REG_EOI = 0x0B,
    LAPIC_REG_CMCI = 0x2F,
    LAPIC_REG_LVT_TIMER = 0x32,
    LAPIC_REG_LVT_LINT0 = 0x35,
    LAPIC_REG_LVT_LINT1 = 0x36,
    LAPIC_REG_LVT_ERROR = 0x37,
    LAPIC_REG_ICR_LOW = 0x30,
    LAPIC_REG_ICR_HIGH = 0x31,
    LAPIC_REG_TIMER_INITIAL_COUNT = 0x38,
    LAPIC_REG_TIMER_CURRENT_COUNT = 0x39,
    LAPIC_REG_TIMER_DIVIDE = 0x3E,
}

enum {
    LAPIC_TIMER_DIVIDE_1 = 0x0B,
    LAPIC_TIMER_PERIODIC = 0x20000,
}

enum {
    LAPIC_LVT_MASKED = 0x10000,
}

struct ApicReg {
    uint val;
    uint[3] padding;
}

struct LocalApic {
    ApicReg[64] regs;

    uint read(int reg) {
        return vld(&regs[reg].val);
    }

    void write(int reg, uint v) {
        vst(&regs[reg].val, v);
    }

    uint id() {
        return read(LAPIC_REG_ID) >> 24;
    }

    void enable(int vector) {
        write(LAPIC_REG_SVR, (read(LAPIC_REG_SVR) & ~0xFF) | 0x100 | vector);
    }

    void disable() {
        write(LAPIC_REG_SVR, read(LAPIC_REG_SVR) & ~0x100);
    }

    uint error() {
        write(LAPIC_REG_ESR, 0);
        return read(LAPIC_REG_ESR);
    }

    void ack() {
        write(LAPIC_REG_EOI, 0);
    }
}

enum {
    IOAPIC_REG_ID = 0x0,
    IOAPIC_REG_VER = 0x1,
    IOAPIC_REG_REDTBL = 0x10,
}

struct IoApic {
    enum REDTBL_MASKED = 0x10000;

    ApicReg[2] regs;

    uint read(int reg) {
        vst(&regs[0].val, 0);
        return vld(&regs[1].val);
    }

    void write(int reg, uint v) {
        vst(&regs[0].val, reg);
        vst(&regs[1].val, v);
    }

    uint id() {
        return read(IOAPIC_REG_ID) >> 24;
    }

    void enable_irq(int entry, int vector, uint lapic_id) {
        write(IOAPIC_REG_REDTBL + 2 * entry, vector);
        write(IOAPIC_REG_REDTBL + 2 * entry + 1, lapic_id << 24);
    }

    void disable_irq(int entry) {
        write(IOAPIC_REG_REDTBL + 2 * entry, REDTBL_MASKED);
        write(IOAPIC_REG_REDTBL + 2 * entry + 1, 0);
    }
}
