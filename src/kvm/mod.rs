mod vm;
mod vcpu;

use crate::hypervisor::{Error, Hypervisor};

pub struct KvmHypervisor {
    kvm: kvm_ioctls::Kvm,
}

impl KvmHypervisor {
    pub fn new() -> Result<Self, Error> {
        let kvm = kvm_ioctls::Kvm::new().map_err(|e| Error::Ioctl(e.into()))?;
        let api_ver = kvm.get_api_version();
        if api_ver != 12 {
            return Err(Error::ApiVersionMismatch);
        }
        Ok(KvmHypervisor { kvm })
    }
}

impl Hypervisor for KvmHypervisor {
    type Vm = vm::KvmVm;

    fn create_vm(&self) -> Result<vm::KvmVm, Error> {
        let vm_fd = self.kvm.create_vm().map_err(|e| Error::Ioctl(e.into()))?;
        Ok(vm::KvmVm::new(vm_fd))
    }
}
