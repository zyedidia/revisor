module arch.arm64.gic;

import arch.arm64.sys;

import core.volatile;

// timer is interrupt number 30?

enum {
    GIC_DIST_BASE = pa2ka(0x100000),
    GIC_REDIST_BASE = pa2ka(0x110000),

    GICV3_GROUP0 = 0,

    GIC_PHYS_TIMER_ID = 30,

    GIC_SIGNAL_ID = 16,
}

struct GICDist {
    uint GICD_CTLR;              // +0x0000 - RW - Distributor Control Register
    uint GICD_TYPER;             // +0x0004 - RO - Interrupt Controller Type Register
    uint GICD_IIDR;              // +0x0008 - RO - Distributor Implementer Identification Register

    uint padding0;               // +0x000C - RESERVED

    uint GICD_STATUSR;           // +0x0010 - RW - Status register

    uint[3] padding1;            // +0x0014 - RESERVED

    uint[8] IMP_DEF;             // +0x0020 - RW - Implementation defined registers

    uint GICD_SETSPI_NSR;        // +0x0040 - WO - Non-secure Set SPI Pending (Used when SPI is signalled using MSI)
    uint padding2;               // +0x0044 - RESERVED
    uint GICD_CLRSPI_NSR;        // +0x0048 - WO - Non-secure Clear SPI Pending (Used when SPI is signalled using MSI)
    uint padding3;               // +0x004C - RESERVED
    uint GICD_SETSPI_SR;         // +0x0050 - WO - Secure Set SPI Pending (Used when SPI is signalled using MSI)
    uint padding4;               // +0x0054 - RESERVED
    uint GICD_CLRSPI_SR;         // +0x0058 - WO - Secure Clear SPI Pending (Used when SPI is signalled using MSI)

    uint[3] padding5;            // +0x005C - RESERVED

    uint GICD_SEIR;              // +0x0068 - WO - System Error Interrupt Register (Note: This was recently removed from the spec)

    uint[5] padding6;            // +0x006C - RESERVED

    uint[32] GICD_IGROUPR;       // +0x0080 - RW - Interrupt Group Registers (Note: In GICv3, need to look at IGROUPR and IGRPMODR)

    uint[32] GICD_ISENABLER;     // +0x0100 - RW - Interrupt Set-Enable Registers
    uint[32] GICD_ICENABLER;     // +0x0180 - RW - Interrupt Clear-Enable Registers
    uint[32] GICD_ISPENDR;       // +0x0200 - RW - Interrupt Set-Pending Registers
    uint[32] GICD_ICPENDR;       // +0x0280 - RW - Interrupt Clear-Pending Registers
    uint[32] GICD_ISACTIVER;     // +0x0300 - RW - Interrupt Set-Active Register
    uint[32] GICD_ICACTIVER;     // +0x0380 - RW - Interrupt Clear-Active Register

    ubyte[1024] GICD_IPRIORITYR; // +0x0400 - RW - Interrupt Priority Registers
    uint[256] GICD_ITARGETSR;    // +0x0800 - RW - Interrupt Processor Targets Registers
    uint[64] GICD_ICFGR;         // +0x0C00 - RW - Interrupt Configuration Registers
    uint[32] GICD_GRPMODR;       // +0x0D00 - RW - Interrupt Group Modifier (Note: In GICv3, need to look at IGROUPR and IGRPMODR)
    uint[32] padding7;           // +0x0D80 - RESERVED
    uint[64] GICD_NSACR;         // +0x0E00 - RW - Non-secure Access Control Register

    uint GICD_SGIR;              // +0x0F00 - WO - Software Generated Interrupt Register

    uint[3] padding8;            // +0x0F04 - RESERVED

    uint[4] GICD_CPENDSGIR;      // +0x0F10 - RW - Clear pending for SGIs
    uint[4] GICD_SPENDSGIR;      // +0x0F20 - RW - Set pending for SGIs

    uint[52] padding9;           // +0x0F30 - RESERVED

    // GICv3.1 extended SPI range
    uint[128] GICD_IGROUPRE;     // +0x1000 - RW - Interrupt Group Registers (GICv3.1)
    uint[128] GICD_ISENABLERE;   // +0x1200 - RW - Interrupt Set-Enable Registers (GICv3.1)
    uint[128] GICD_ICENABLERE;   // +0x1400 - RW - Interrupt Clear-Enable Registers (GICv3.1)
    uint[128] GICD_ISPENDRE;     // +0x1600 - RW - Interrupt Set-Pending Registers (GICv3.1)
    uint[128] GICD_ICPENDRE;     // +0x1800 - RW - Interrupt Clear-Pending Registers (GICv3.1)
    uint[128] GICD_ISACTIVERE;   // +0x1A00 - RW - Interrupt Set-Active Register (GICv3.1)
    uint[128] GICD_ICACTIVERE;   // +0x1C00 - RW - Interrupt Clear-Active Register (GICv3.1)

    uint[128] padding10;         // +0x1E00 - RESERVED

    ubyte[4096] GICD_IPRIORITYRE; // +0x2000 - RW - Interrupt Priority Registers (GICv3.1)

    uint[256] GICD_ICFGRE;       // +0x3000 - RW - Interrupt Configuration Registers (GICv3.1)
    uint[128] GICD_IGRPMODRE;    // +0x3400 - RW - Interrupt Group Modifier (GICv3.1)
    uint[256] GICD_NSACRE;       // +0x3600 - RW - Non-secure Access Control Register (GICv3.1)

    uint[2432] padding11;        // +0x3A00 - RESERVED

    // GICv3.0
    ulong[1024] GICD_ROUTER;      // +0x6000 - RW - Controls SPI routing when ARE=1

    // GICv3.1
    ulong[1024] GICD_ROUTERE;     // +0x8000 - RW - Controls SPI routing when ARE=1 (GICv3.1)
}

struct GICRedistLPIS {
    uint GICR_CTLR;             // +0x0000 - RW - Redistributor Control Register
    uint GICR_IIDR;             // +0x0004 - RO - Redistributor Implementer Identification Register
    uint[2] GICR_TYPER;         // +0x0008 - RO - Redistributor Type Register
    uint GICR_STATUSR;          // +0x0010 - RW - Redistributor Status register
    uint GICR_WAKER;            // +0x0014 - RW - Wake Request Registers
    uint GICR_MPAMIDR;          // +0x0018 - RO - Reports maximum PARTID and PMG (GICv3.1)
    uint GICR_PARTID;           // +0x001C - RW - Set PARTID and PMG used for Redistributor memory accesses (GICv3.1)
    uint[8] padding1;           // +0x0020 - RESERVED
    ulong GICR_SETLPIR;          // +0x0040 - WO - Set LPI pending (Note: IMP DEF if ITS present)
    ulong GICR_CLRLPIR;          // +0x0048 - WO - Set LPI pending (Note: IMP DEF if ITS present)
    uint[6] padding2;           // +0x0058 - RESERVED
    uint GICR_SEIR;             // +0x0068 - WO - (Note: This was removed from the spec)
    uint padding3;              // +0x006C - RESERVED
    ulong GICR_PROPBASER;        // +0x0070 - RW - Sets location of the LPI configuration table
    ulong GICR_PENDBASER;        // +0x0078 - RW - Sets location of the LPI pending table
    uint[8] padding4;           // +0x0080 - RESERVED
    ulong GICR_INVLPIR;          // +0x00A0 - WO - Invalidates cached LPI config (Note: In GICv3.x: IMP DEF if ITS present)
    uint[2] padding5;           // +0x00A8 - RESERVED
    ulong GICR_INVALLR;          // +0x00B0 - WO - Invalidates cached LPI config (Note: In GICv3.x: IMP DEF if ITS present)
    uint[2] padding6;           // +0x00B8 - RESERVED
    ulong GICR_SYNCR;            // +0x00C0 - WO - Redistributor Sync
    uint[2] padding7;           // +0x00C8 - RESERVED
    uint[12] padding8;          // +0x00D0 - RESERVED
    ulong GICR_MOVLPIR;          // +0x0100 - WO - IMP DEF
    uint[2] padding9;           // +0x0108 - RESERVED
    ulong GICR_MOVALLR;          // +0x0110 - WO - IMP DEF
    uint[2] padding10;          // +0x0118 - RESERVED
}

struct GICRedistSGIS {
    uint[32] padding1;          // +0x0000 - RESERVED
    uint[3] GICR_IGROUPR;       // +0x0080 - RW - Interrupt Group Registers (Security Registers in GICv1)
    uint[29] padding2;          // +0x008C - RESERVED
    uint[3] GICR_ISENABLER;     // +0x0100 - RW - Interrupt Set-Enable Registers
    uint[29] padding3;          // +0x010C - RESERVED
    uint[3] GICR_ICENABLER;     // +0x0180 - RW - Interrupt Clear-Enable Registers
    uint[29] padding4;          // +0x018C - RESERVED
    uint[3] GICR_ISPENDR;       // +0x0200 - RW - Interrupt Set-Pending Registers
    uint[29] padding5;          // +0x020C - RESERVED
    uint[3] GICR_ICPENDR;       // +0x0280 - RW - Interrupt Clear-Pending Registers
    uint[29] padding6;          // +0x028C - RESERVED
    uint[3] GICR_ISACTIVER;     // +0x0300 - RW - Interrupt Set-Active Register
    uint[29] padding7;          // +0x030C - RESERVED
    uint[3] GICR_ICACTIVER;     // +0x0380 - RW - Interrupt Clear-Active Register
    uint[29] padding8;          // +0x018C - RESERVED
    ubyte[96] GICR_IPRIORITYR;  // +0x0400 - RW - Interrupt Priority Registers
    uint[488] padding9;         // +0x0460 - RESERVED
    uint[6] GICR_ICFGR;         // +0x0C00 - RW - Interrupt Configuration Registers
    uint[58] padding10;	      // +0x0C18 - RESERVED
    uint[3] GICR_IGRPMODR;      // +0x0D00 - RW - Interrupt Group Modifier Register
    uint[61] padding11;	      // +0x0D0C - RESERVED
    uint GICR_NSACR;            // +0x0E00 - RW - Non-secure Access Control Register
}

struct GICv3_rdist_vlpis_if {
    uint[28] padding1;           // +0x0000 - RESERVED
    ulong GICR_VPROPBASER;       // +0x0070 - RW - Sets location of the LPI vPE Configuration table
    ulong GICR_VPENDBASER;       // +0x0078 - RW - Sets location of the LPI Pending table
}

struct GICv3_rdist_res_if {
    uint[32] padding1;          // +0x0000 - RESERVED
}

struct GICRedist {
    GICRedistLPIS lpis;
    // align to 64K
    ubyte[0x10000 - GICRedistLPIS.sizeof] _pad1;

    GICRedistSGIS sgis;
    ubyte[0x10000 - GICRedistSGIS.sizeof] _pad2;
}

private __gshared {
    GICDist* dist;
    GICRedist* redist;

    uint max_rd = 0;
}

void gic_init(uint affinity, uintptr dist_base, uintptr redist_base) {
    SysReg.icc_sre_el1 = 1;
    isb();

    gic_enable(dist_base, redist_base);

    uint rd = gic_redist_id(affinity);
    assert(rd != uint.max, "invalid redist ID");
    gic_wakeup_redist(rd);

    // priority mask
    SysReg.icc_pmr_el1 = 0xff;
    // group 0 interrupts
    SysReg.icc_igrpen0_el1 = 1;
    // group 1 interrupts
    SysReg.icc_igrpen1_el1 = SysReg.icc_igrpen1_el1 | 1;
    isb();

    gic_set_int_priority(GIC_PHYS_TIMER_ID, rd, 0);
    gic_set_int_group(GIC_PHYS_TIMER_ID, rd, GICV3_GROUP0);
    gic_enable_int(GIC_PHYS_TIMER_ID, rd);

    gic_set_int_priority(16, rd, 0);
    gic_set_int_group(16, rd, GICV3_GROUP0);
    gic_enable_int(16, rd);
}

void gic_enable(uintptr dist_base, uintptr redist_base) {
    dist = cast(GICDist*) dist_base;
    redist = cast(GICRedist*) redist_base;

    uint index;

    while ((vld(&redist[index].lpis.GICR_TYPER[0]) & (1 << 4)) == 0) {
        index++;
    }
    max_rd = index;

    // Set ARE bits.
    vst(&dist.GICD_CTLR, (1 << 5) | (1 << 4));

    // Register layout is now different after setting ARE.
    vst(&dist.GICD_CTLR, 7 | (1 << 5) | (1 << 4));
}

uint gic_redist_id(uint affinity) {
    uint index;
    do {
        if (vld(&redist[index].lpis.GICR_TYPER[1]) == affinity) {
            return index;
        }
        index++;
    } while (index <= max_rd);
    return uint.max;
}

void gic_wakeup_redist(uint rd) {
    uint tmp = vld(&redist[rd].lpis.GICR_WAKER);
    tmp = tmp & ~0x2;
    vst(&redist[rd].lpis.GICR_WAKER, tmp);

    // Poll ChildrenAsleep bit until Redistributor wakes.
    do {
        tmp = vld(&redist[rd].lpis.GICR_WAKER);
    } while ((tmp & 0x4) != 0);
}

bool gic_set_int_priority(uint id, uint rd, ubyte priority) {
    assert(id < 31);

    if (rd > max_rd)
        return false;
    vst(&redist[rd].sgis.GICR_IPRIORITYR[id], priority);
    return true;
}

bool gic_set_int_group(uint id, uint rd, uint security) {
    assert(id < 31);

    if (rd > max_rd)
        return false;
    id = id & 0x1f;
    id = 1 << id;

    uint group = vld(&redist[rd].sgis.GICR_IGROUPR[0]);
    uint mod = vld(&redist[rd].sgis.GICR_IGRPMODR[0]);

    assert(security == GICV3_GROUP0);
    group = (group & ~id);
    mod = (mod & ~id);

    vst(&redist[rd].sgis.GICR_IGROUPR[0], group);
    vst(&redist[rd].sgis.GICR_IGRPMODR[0], mod);

    return true;
}

bool gic_enable_int(uint id, uint rd) {
    assert(id < 31);

    if (rd > max_rd)
        return false;

    id = id & 0x1f;
    id = 1 << id;
    vst(&redist[rd].sgis.GICR_ISENABLER[0], id);

    return true;
}
