use kvm_ioctls::VmFd;
use crate::hypervisor::{Error, Vm};

use super::vcpu::KvmVcpu;

pub struct KvmVm {
    fd: VmFd,
}

impl KvmVm {
    pub(crate) fn new(fd: VmFd) -> Self {
        KvmVm { fd }
    }

    /// Perform x86_64-specific VM initialization (TSS, IRQ chip).
    /// Must be called before creating vCPUs.
    pub fn init_x86_64(&self) -> Result<(), Error> {
        // Set TSS address (required by Intel VT-x, harmless on AMD).
        self.fd
            .set_tss_address(0xfffb_d000)
            .map_err(|e| Error::Ioctl(std::io::Error::from_raw_os_error(e.errno())))?;
        // Create in-kernel IRQ chip (required for APIC).
        self.fd
            .create_irq_chip()
            .map_err(|e| Error::Ioctl(std::io::Error::from_raw_os_error(e.errno())))?;
        Ok(())
    }
}

impl Vm for KvmVm {
    type Vcpu = KvmVcpu;

    fn add_memory_region(
        &self,
        slot: u32,
        guest_addr: u64,
        host_ptr: *mut u8,
        size: usize,
    ) -> Result<(), Error> {
        let mem_region = kvm_bindings::kvm_userspace_memory_region {
            slot,
            guest_phys_addr: guest_addr,
            memory_size: size as u64,
            userspace_addr: host_ptr as u64,
            flags: 0,
        };
        unsafe {
            self.fd
                .set_user_memory_region(mem_region)
                .map_err(|e| Error::Ioctl(e.into()))?;
        }
        Ok(())
    }

    fn remove_memory_region(&self, slot: u32) -> Result<(), Error> {
        let mem_region = kvm_bindings::kvm_userspace_memory_region {
            slot,
            guest_phys_addr: 0,
            memory_size: 0,
            userspace_addr: 0,
            flags: 0,
        };
        unsafe {
            self.fd
                .set_user_memory_region(mem_region)
                .map_err(|e| Error::Ioctl(e.into()))?;
        }
        Ok(())
    }

    fn create_vcpu(&self, id: u32) -> Result<KvmVcpu, Error> {
        let vcpu_fd = self
            .fd
            .create_vcpu(id as u64)
            .map_err(|e| Error::Ioctl(e.into()))?;
        Ok(KvmVcpu::new(vcpu_fd))
    }
}
