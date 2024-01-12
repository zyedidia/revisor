module arch.arm64.gic;

import arch.arm64.sys;

import core.volatile;

// timer is interrupt number 30?

enum {
    GICC_BASE = pa2ka(0x3ffd0000),
    GICD_BASE = pa2ka(0x3fff0000),

    GICC_PMR_PRIO_LOW = 0xff,
    GICC_BPR_NO_GROUP = 0x00,

    GICD_ISENABLER_SIZE = 32,
    GICD_ICPENDR_SIZE = 32,
    GICD_ITARGETSR_SIZE = 32,
    GICD_IPRIORITY_SIZE = 4,
    GICD_ICFGR_SIZE = 16,

    GICD_ITARGETSR_BITS = 8,
    GICD_IPRIORITY_BITS = 8,
    GICD_ICFGR_BITS = 2,

    GIC_ICFGR_EDGE = 2,
}

struct GICCpu {
    uint ctlr;
    uint pmr;
    uint bpr;
}

struct GICDist {
    uint ctlr;
}

private __gshared {
    GICCpu* gic_cpu = cast(GICCpu*) GICC_BASE;
    GICDist* gic_dist = cast(GICDist*) GICD_BASE;

    uint* gicd_isenabler = cast(uint*) (GICD_BASE + 0x100);
    uint* gicd_icpendr = cast(uint*) (GICD_BASE + 0x280);
    uint* gicd_itargetsr = cast(uint*) (GICD_BASE + 0x800);
    uint* gicd_ipriorityr = cast(uint*) (GICD_BASE + 0x400);
    uint* gicd_icfgr = cast(uint*) (GICD_BASE + 0xc00);
}

void gic_init() {
    printf("%d\n", vld(&gic_dist.ctlr));
    vst(&gic_dist.ctlr, 1);
    vst(&gic_cpu.ctlr, 1);
    vst(&gic_cpu.pmr, GICC_PMR_PRIO_LOW);
    vst(&gic_cpu.bpr, GICC_BPR_NO_GROUP);
}

void gic_enable(uint intr) {
    vst(&gicd_isenabler[intr / GICD_ISENABLER_SIZE], 1 << (intr % GICD_ISENABLER_SIZE));
}

void gic_clear(uint intr) {
    vst(&gicd_icpendr[intr / GICD_ICPENDR_SIZE], 1 << (intr % GICD_ICPENDR_SIZE));
}

void gic_set_core(uint intr, uint core) {
    uint shift = (intr % GICD_ITARGETSR_SIZE) * GICD_ITARGETSR_BITS;
    uint* addr = &gicd_itargetsr[intr / GICD_ITARGETSR_SIZE];
    uint value = vld(addr);
    value &= !(0xff << shift);
    value |= core << shift;
    vst(addr, value);
}

void gic_set_priority(uint intr, uint priority) {
    uint shift = (intr % GICD_IPRIORITY_SIZE) * GICD_IPRIORITY_BITS;
    uint* addr = &gicd_ipriorityr[intr / GICD_IPRIORITY_SIZE];
    uint value = vld(addr);
    value &= !(0xff << shift);
    value |= priority << shift;
    vst(addr, value);
}

void gic_set_config(uint intr, uint config) {
    uint shift = (intr / GICD_ICFGR_SIZE) * GICD_ICFGR_BITS;
    uint* addr = &gicd_icfgr[intr / GICD_ICFGR_SIZE];
    uint value = vld(addr);
    value &= !(0x03 << shift);
    value |= config << shift;
    vst(addr, value);
}
