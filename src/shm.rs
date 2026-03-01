pub struct SharedMemory {
    pub host_ptr: *mut u8,
    pub size: usize,
    /// KVM memory region slot assigned when mapped into guest (if any).
    pub guest_slot: Option<u32>,
    pub guest_addr: Option<u64>,
}

impl SharedMemory {
    pub fn new(host_ptr: *mut u8, size: usize) -> Self {
        SharedMemory {
            host_ptr,
            size,
            guest_slot: None,
            guest_addr: None,
        }
    }
}

impl Drop for SharedMemory {
    fn drop(&mut self) {
        if !self.host_ptr.is_null() {
            unsafe {
                libc::munmap(self.host_ptr as *mut libc::c_void, self.size);
            }
        }
    }
}
