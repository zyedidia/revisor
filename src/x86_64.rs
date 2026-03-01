use crate::hypervisor::{Error, Vcpu};

pub trait VcpuX86_64: Vcpu {
    fn get_regs(&self) -> Result<Regs, Error>;
    fn set_regs(&mut self, regs: &Regs) -> Result<(), Error>;
    fn get_sregs(&self) -> Result<Sregs, Error>;
    fn set_sregs(&mut self, sregs: &Sregs) -> Result<(), Error>;
}

// Memory layout constants.
pub const PML4_ADDR: u64 = 0x1000;
pub const PDPT_ADDR: u64 = 0x2000;
pub const PD_ADDR: u64 = 0x3000;
pub const GDT_ADDR: u64 = 0x4000;
pub const GUEST_LOAD_ADDR: u64 = 0x10_0000; // 1MB
pub const GUEST_MEM_SIZE: usize = 0x400_0000; // 64MB
pub const HYPERCALL_ADDR: u64 = 0x400_0000; // right after guest RAM
pub const STACK_TOP: u64 = GUEST_LOAD_ADDR; // stack grows down from 1MB

// GDT selector indices.
pub const GDT_NULL: u16 = 0;
pub const GDT_CODE64: u16 = 1;
pub const GDT_DATA: u16 = 2;
pub const GDT_TSS: u16 = 3;
pub const GDT_ENTRY_COUNT: usize = 4;

/// Platform-agnostic general-purpose registers.
#[derive(Debug, Default, Clone)]
pub struct Regs {
    pub rax: u64,
    pub rbx: u64,
    pub rcx: u64,
    pub rdx: u64,
    pub rsi: u64,
    pub rdi: u64,
    pub rsp: u64,
    pub rbp: u64,
    pub r8: u64,
    pub r9: u64,
    pub r10: u64,
    pub r11: u64,
    pub r12: u64,
    pub r13: u64,
    pub r14: u64,
    pub r15: u64,
    pub rip: u64,
    pub rflags: u64,
}

/// A segment register descriptor.
#[derive(Debug, Default, Clone, Copy)]
pub struct Segment {
    pub base: u64,
    pub limit: u32,
    pub selector: u16,
    pub type_: u8,
    pub present: u8,
    pub dpl: u8,
    pub db: u8,
    pub s: u8,
    pub l: u8,
    pub g: u8,
    pub avl: u8,
    pub unusable: u8,
}

/// Descriptor table register (GDT/IDT).
#[derive(Debug, Default, Clone, Copy)]
pub struct DescriptorTable {
    pub base: u64,
    pub limit: u16,
}

/// Platform-agnostic special registers.
#[derive(Debug, Default, Clone)]
pub struct Sregs {
    pub cs: Segment,
    pub ds: Segment,
    pub es: Segment,
    pub fs: Segment,
    pub gs: Segment,
    pub ss: Segment,
    pub tr: Segment,
    pub ldt: Segment,
    pub gdt: DescriptorTable,
    pub idt: DescriptorTable,
    pub cr0: u64,
    pub cr2: u64,
    pub cr3: u64,
    pub cr4: u64,
    pub efer: u64,
}

// CR0 bits.
const CR0_PE: u64 = 1 << 0;
const CR0_ET: u64 = 1 << 4;
const CR0_PG: u64 = 1 << 31;

// CR4 bits.
const CR4_PAE: u64 = 1 << 5;

// EFER bits.
const EFER_LME: u64 = 1 << 8;
const EFER_LMA: u64 = 1 << 10;

/// Construct a GDT entry from flags, base, and limit.
/// Follows the x86 segment descriptor format.
pub fn gdt_entry(flags: u16, base: u32, limit: u32) -> u64 {
    ((u64::from(base) & 0xff00_0000) << (56 - 24))
        | ((u64::from(flags) & 0x0000_f0ff) << 40)
        | ((u64::from(limit) & 0x000f_0000) << (48 - 16))
        | ((u64::from(base) & 0x00ff_ffff) << 16)
        | (u64::from(limit) & 0x0000_ffff)
}

/// Build a `Segment` from a raw GDT entry and its table index.
pub fn segment_from_gdt(entry: u64, table_index: u16) -> Segment {
    let get_base = |e: u64| -> u64 {
        ((e & 0xFF00_0000_0000_0000) >> 32)
            | ((e & 0x0000_00FF_0000_0000) >> 16)
            | ((e & 0x0000_0000_FFFF_0000) >> 16)
    };
    let get_g = |e: u64| -> u8 { ((e >> 55) & 1) as u8 };
    let get_limit = |e: u64| -> u32 {
        let raw = ((((e) & 0x000F_0000_0000_0000) >> 32) | ((e) & 0x0000_0000_0000_FFFF)) as u32;
        match get_g(e) {
            0 => raw,
            _ => (raw << 12) | 0xFFF,
        }
    };
    let get_p = |e: u64| -> u8 { ((e >> 47) & 1) as u8 };

    Segment {
        base: get_base(entry),
        limit: get_limit(entry),
        selector: table_index * 8,
        type_: ((entry >> 40) & 0xF) as u8,
        present: get_p(entry),
        dpl: ((entry >> 45) & 3) as u8,
        db: ((entry >> 54) & 1) as u8,
        s: ((entry >> 44) & 1) as u8,
        l: ((entry >> 53) & 1) as u8,
        g: get_g(entry),
        avl: ((entry >> 52) & 1) as u8,
        unusable: if get_p(entry) == 0 { 1 } else { 0 },
    }
}

/// Write identity-mapped page tables (first 1GB using 2MB pages) into guest memory.
pub fn setup_page_tables(mem: &mut [u8]) {
    let write_u64 = |mem: &mut [u8], offset: u64, val: u64| {
        let off = offset as usize;
        mem[off..off + 8].copy_from_slice(&val.to_le_bytes());
    };

    // PML4[0] -> PDPT
    write_u64(mem, PML4_ADDR, PDPT_ADDR | 0x03);

    // PDPT[0] -> PD
    write_u64(mem, PDPT_ADDR, PD_ADDR | 0x03);

    // PD: 512 entries, each mapping 2MB (0x83 = present | writable | page size)
    for i in 0u64..512 {
        write_u64(mem, PD_ADDR + i * 8, (i << 21) | 0x83);
    }
}

/// Write a minimal GDT (null, code64, data, tss) into guest memory.
/// Returns the raw GDT entries.
pub fn setup_gdt(mem: &mut [u8]) -> [u64; GDT_ENTRY_COUNT] {
    let gdt = [
        gdt_entry(0, 0, 0),            // NULL
        gdt_entry(0xa09b, 0, 0xfffff), // CODE64: L=1, D=0, present, code, G=1
        gdt_entry(0xc093, 0, 0xfffff), // DATA: D/B=1, writable, present, data, G=1
        gdt_entry(0x808b, 0, 0xfffff), // TSS: present, 64-bit TSS (busy), G=1
    ];

    let write_u64 = |mem: &mut [u8], offset: u64, val: u64| {
        let off = offset as usize;
        mem[off..off + 8].copy_from_slice(&val.to_le_bytes());
    };

    for (i, entry) in gdt.iter().enumerate() {
        write_u64(mem, GDT_ADDR + (i as u64) * 8, *entry);
    }

    gdt
}

/// Configure special registers for 64-bit long mode.
pub fn setup_long_mode_sregs(gdt: &[u64; GDT_ENTRY_COUNT]) -> Sregs {
    let code_seg = segment_from_gdt(gdt[GDT_CODE64 as usize], GDT_CODE64);
    let data_seg = segment_from_gdt(gdt[GDT_DATA as usize], GDT_DATA);
    let tss_seg = segment_from_gdt(gdt[GDT_TSS as usize], GDT_TSS);

    Sregs {
        cs: code_seg,
        ds: data_seg,
        es: data_seg,
        fs: data_seg,
        gs: data_seg,
        ss: data_seg,
        tr: tss_seg,
        ldt: Segment::default(),
        gdt: DescriptorTable {
            base: GDT_ADDR,
            limit: (std::mem::size_of::<u64>() * GDT_ENTRY_COUNT) as u16 - 1,
        },
        idt: DescriptorTable::default(),
        cr0: CR0_PE | CR0_ET | CR0_PG,
        cr2: 0,
        cr3: PML4_ADDR,
        cr4: CR4_PAE,
        efer: EFER_LME | EFER_LMA,
    }
}

/// Configure initial general-purpose registers.
pub fn setup_initial_regs(entry: u64, stack_top: u64) -> Regs {
    Regs {
        rip: entry,
        rsp: stack_top,
        rbp: stack_top,
        rflags: 0x2,
        ..Default::default()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_gdt_entry_null() {
        assert_eq!(gdt_entry(0, 0, 0), 0);
    }

    #[test]
    fn test_gdt_entry_code64() {
        let entry = gdt_entry(0xa09b, 0, 0xfffff);
        let seg = segment_from_gdt(entry, 1);
        assert_eq!(seg.l, 1);       // long mode
        assert_eq!(seg.db, 0);      // must be 0 for 64-bit
        assert_eq!(seg.g, 1);       // granularity
        assert_eq!(seg.present, 1);
        assert_eq!(seg.s, 1);       // code/data (not system)
        assert_eq!(seg.type_, 0xb); // execute/read, accessed
        assert_eq!(seg.selector, 8);
        assert_eq!(seg.base, 0);
        assert_eq!(seg.limit, 0xffff_ffff);
    }

    #[test]
    fn test_gdt_entry_data() {
        let entry = gdt_entry(0xc093, 0, 0xfffff);
        let seg = segment_from_gdt(entry, 2);
        assert_eq!(seg.l, 0);
        assert_eq!(seg.db, 1);
        assert_eq!(seg.g, 1);
        assert_eq!(seg.present, 1);
        assert_eq!(seg.s, 1);
        assert_eq!(seg.type_, 0x3); // read/write, accessed
        assert_eq!(seg.selector, 16);
        assert_eq!(seg.limit, 0xffff_ffff);
    }

    #[test]
    fn test_page_tables() {
        let mut mem = vec![0u8; 0x10000];
        setup_page_tables(&mut mem);

        let read_u64 = |off: u64| -> u64 {
            let o = off as usize;
            u64::from_le_bytes(mem[o..o + 8].try_into().unwrap())
        };

        // PML4[0] points to PDPT
        assert_eq!(read_u64(PML4_ADDR), PDPT_ADDR | 0x03);
        // PDPT[0] points to PD
        assert_eq!(read_u64(PDPT_ADDR), PD_ADDR | 0x03);
        // PD entries: identity map with 2MB pages
        for i in 0u64..512 {
            assert_eq!(read_u64(PD_ADDR + i * 8), (i << 21) | 0x83);
        }
    }

    #[test]
    fn test_long_mode_sregs() {
        let mut mem = vec![0u8; 0x10000];
        let gdt = setup_gdt(&mut mem);
        let sregs = setup_long_mode_sregs(&gdt);

        assert_eq!(sregs.cr0 & CR0_PE, CR0_PE);
        assert_eq!(sregs.cr0 & CR0_PG, CR0_PG);
        assert_eq!(sregs.cr4 & CR4_PAE, CR4_PAE);
        assert_eq!(sregs.efer & EFER_LME, EFER_LME);
        assert_eq!(sregs.efer & EFER_LMA, EFER_LMA);
        assert_eq!(sregs.cr3, PML4_ADDR);
        assert_eq!(sregs.cs.l, 1);
    }
}
