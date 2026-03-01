use kvm_ioctls::VcpuFd;
use crate::hypervisor::{Error, Vcpu, VcpuExit};
use crate::x86_64::{DescriptorTable, Regs, Segment, Sregs, VcpuX86_64};

pub struct KvmVcpu {
    fd: VcpuFd,
}

impl KvmVcpu {
    pub(crate) fn new(fd: VcpuFd) -> Self {
        KvmVcpu { fd }
    }
}

impl Vcpu for KvmVcpu {
    fn run(&mut self) -> Result<VcpuExit, Error> {
        match self.fd.run() {
            Ok(exit) => Ok(translate_exit(exit)),
            Err(e) => {
                if e.errno() == libc::EAGAIN || e.errno() == libc::EINTR {
                    // Signal interrupted, re-run
                    Ok(translate_exit(self.fd.run().map_err(|e| Error::Ioctl(e.into()))?))
                } else {
                    Err(Error::Ioctl(e.into()))
                }
            }
        }
    }
}

impl VcpuX86_64 for KvmVcpu {
    fn get_regs(&self) -> Result<Regs, Error> {
        let kvm_regs = self.fd.get_regs().map_err(|e| Error::Ioctl(e.into()))?;
        Ok(from_kvm_regs(&kvm_regs))
    }

    fn set_regs(&mut self, regs: &Regs) -> Result<(), Error> {
        let kvm_regs = to_kvm_regs(regs);
        self.fd
            .set_regs(&kvm_regs)
            .map_err(|e| Error::Ioctl(e.into()))?;
        Ok(())
    }

    fn get_sregs(&self) -> Result<Sregs, Error> {
        let kvm_sregs = self.fd.get_sregs().map_err(|e| Error::Ioctl(e.into()))?;
        Ok(from_kvm_sregs(&kvm_sregs))
    }

    fn set_sregs(&mut self, sregs: &Sregs) -> Result<(), Error> {
        let kvm_sregs = to_kvm_sregs(sregs);
        self.fd
            .set_sregs(&kvm_sregs)
            .map_err(|e| Error::Ioctl(e.into()))?;
        Ok(())
    }
}

fn translate_exit(exit: kvm_ioctls::VcpuExit) -> VcpuExit {
    match exit {
        kvm_ioctls::VcpuExit::MmioRead(addr, data) => VcpuExit::Mmio {
            addr,
            is_write: false,
            len: data.len() as u8,
        },
        kvm_ioctls::VcpuExit::MmioWrite(addr, data) => VcpuExit::Mmio {
            addr,
            is_write: true,
            len: data.len() as u8,
        },
        kvm_ioctls::VcpuExit::Hlt => VcpuExit::Hlt,
        kvm_ioctls::VcpuExit::Shutdown => VcpuExit::Shutdown,
        kvm_ioctls::VcpuExit::FailEntry(reason, _) => VcpuExit::FailEntry { reason },
        kvm_ioctls::VcpuExit::InternalError => VcpuExit::InternalError,
        other => {
            eprintln!("unexpected KVM exit: {:?}", other);
            VcpuExit::InternalError
        }
    }
}

fn from_kvm_regs(k: &kvm_bindings::kvm_regs) -> Regs {
    Regs {
        rax: k.rax,
        rbx: k.rbx,
        rcx: k.rcx,
        rdx: k.rdx,
        rsi: k.rsi,
        rdi: k.rdi,
        rsp: k.rsp,
        rbp: k.rbp,
        r8: k.r8,
        r9: k.r9,
        r10: k.r10,
        r11: k.r11,
        r12: k.r12,
        r13: k.r13,
        r14: k.r14,
        r15: k.r15,
        rip: k.rip,
        rflags: k.rflags,
    }
}

fn to_kvm_regs(r: &Regs) -> kvm_bindings::kvm_regs {
    kvm_bindings::kvm_regs {
        rax: r.rax,
        rbx: r.rbx,
        rcx: r.rcx,
        rdx: r.rdx,
        rsi: r.rsi,
        rdi: r.rdi,
        rsp: r.rsp,
        rbp: r.rbp,
        r8: r.r8,
        r9: r.r9,
        r10: r.r10,
        r11: r.r11,
        r12: r.r12,
        r13: r.r13,
        r14: r.r14,
        r15: r.r15,
        rip: r.rip,
        rflags: r.rflags,
    }
}

fn from_kvm_segment(k: &kvm_bindings::kvm_segment) -> Segment {
    Segment {
        base: k.base,
        limit: k.limit,
        selector: k.selector,
        type_: k.type_,
        present: k.present,
        dpl: k.dpl,
        db: k.db,
        s: k.s,
        l: k.l,
        g: k.g,
        avl: k.avl,
        unusable: k.unusable,
    }
}

fn to_kvm_segment(s: &Segment) -> kvm_bindings::kvm_segment {
    kvm_bindings::kvm_segment {
        base: s.base,
        limit: s.limit,
        selector: s.selector,
        type_: s.type_,
        present: s.present,
        dpl: s.dpl,
        db: s.db,
        s: s.s,
        l: s.l,
        g: s.g,
        avl: s.avl,
        unusable: s.unusable,
        padding: 0,
    }
}

fn from_kvm_dtable(k: &kvm_bindings::kvm_dtable) -> DescriptorTable {
    DescriptorTable {
        base: k.base,
        limit: k.limit,
    }
}

fn to_kvm_dtable(d: &DescriptorTable) -> kvm_bindings::kvm_dtable {
    kvm_bindings::kvm_dtable {
        base: d.base,
        limit: d.limit,
        padding: [0; 3],
    }
}

fn from_kvm_sregs(k: &kvm_bindings::kvm_sregs) -> Sregs {
    Sregs {
        cs: from_kvm_segment(&k.cs),
        ds: from_kvm_segment(&k.ds),
        es: from_kvm_segment(&k.es),
        fs: from_kvm_segment(&k.fs),
        gs: from_kvm_segment(&k.gs),
        ss: from_kvm_segment(&k.ss),
        tr: from_kvm_segment(&k.tr),
        ldt: from_kvm_segment(&k.ldt),
        gdt: from_kvm_dtable(&k.gdt),
        idt: from_kvm_dtable(&k.idt),
        cr0: k.cr0,
        cr2: k.cr2,
        cr3: k.cr3,
        cr4: k.cr4,
        efer: k.efer,
    }
}

fn to_kvm_sregs(s: &Sregs) -> kvm_bindings::kvm_sregs {
    kvm_bindings::kvm_sregs {
        cs: to_kvm_segment(&s.cs),
        ds: to_kvm_segment(&s.ds),
        es: to_kvm_segment(&s.es),
        fs: to_kvm_segment(&s.fs),
        gs: to_kvm_segment(&s.gs),
        ss: to_kvm_segment(&s.ss),
        tr: to_kvm_segment(&s.tr),
        ldt: to_kvm_segment(&s.ldt),
        gdt: to_kvm_dtable(&s.gdt),
        idt: to_kvm_dtable(&s.idt),
        cr0: s.cr0,
        cr2: s.cr2,
        cr3: s.cr3,
        cr4: s.cr4,
        efer: s.efer,
        cr8: 0,
        apic_base: 0,
        interrupt_bitmap: [0; 4],
    }
}
