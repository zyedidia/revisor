#[derive(Debug)]
pub enum VcpuExit {
    Mmio { addr: u64, is_write: bool, len: u8 },
    Hlt,
    Shutdown,
    FailEntry { reason: u64 },
    InternalError,
}

pub trait Hypervisor {
    type Vm: Vm;
    fn create_vm(&self) -> Result<Self::Vm, Error>;
}

pub trait Vm {
    type Vcpu: Vcpu;

    fn add_memory_region(
        &self,
        slot: u32,
        guest_addr: u64,
        host_ptr: *mut u8,
        size: usize,
    ) -> Result<(), Error>;

    fn remove_memory_region(&self, slot: u32) -> Result<(), Error>;

    fn create_vcpu(&self, id: u32) -> Result<Self::Vcpu, Error>;
}

pub trait Vcpu {
    fn run(&mut self) -> Result<VcpuExit, Error>;
}

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("ioctl failed: {0}")]
    Ioctl(#[from] std::io::Error),
    #[error("kvm api version mismatch")]
    ApiVersionMismatch,
    #[error("{0}")]
    Other(String),
}
