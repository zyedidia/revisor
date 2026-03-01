mod channel;
mod handle;
mod hypercall;
mod hypervisor;
mod kvm;
mod shm;
mod signal;
mod x86_64;

use std::fs;
use std::ptr;

use anyhow::{bail, Context, Result};

use crate::hypervisor::{Hypervisor, Vcpu, VcpuExit, Vm};
use crate::x86_64::{VcpuX86_64, GUEST_MEM_SIZE, HYPERCALL_ADDR, STACK_TOP};
use crate::kvm::KvmHypervisor;

use crate::channel::{Channel, Message};
use crate::handle::{HandleTable, Resource};
use crate::hypercall::*;
use crate::shm::SharedMemory;
use crate::signal::Signal;

struct VmState {
    handles: HandleTable,
    /// Guest memory slice (for reading/writing guest data).
    guest_mem: *mut u8,
    guest_mem_size: usize,
    /// Next KVM memory region slot for shared memory mappings.
    next_slot: u32,
    /// Next guest physical address for shared memory mappings.
    /// Starts above the hypercall device page.
    next_guest_addr: u64,
}

impl VmState {
    fn new(guest_mem: *mut u8, guest_mem_size: usize) -> Self {
        VmState {
            handles: HandleTable::new(),
            guest_mem,
            guest_mem_size,
            next_slot: 1, // slot 0 is main guest memory
            next_guest_addr: HYPERCALL_ADDR + 0x1000, // page after the hypercall device
        }
    }

    fn guest_slice(&self, guest_addr: u64, len: usize) -> Option<&[u8]> {
        if guest_addr as usize + len <= self.guest_mem_size {
            unsafe { Some(std::slice::from_raw_parts(self.guest_mem.add(guest_addr as usize), len)) }
        } else {
            None
        }
    }

    fn guest_slice_mut(&self, guest_addr: u64, len: usize) -> Option<&mut [u8]> {
        if guest_addr as usize + len <= self.guest_mem_size {
            unsafe {
                Some(std::slice::from_raw_parts_mut(
                    self.guest_mem.add(guest_addr as usize),
                    len,
                ))
            }
        } else {
            None
        }
    }

    fn dispatch<V: Vm>(
        &mut self,
        vm: &V,
        nr: u64,
        a0: u64,
        a1: u64,
        a2: u64,
        a3: u64,
        _a4: u64,
        _a5: u64,
    ) -> i64 {
        match nr {
            HC_EXIT => {
                std::process::exit(a0 as i32);
            }
            HC_CHANNEL_CREATE => self.hc_channel_create(),
            HC_CHANNEL_SEND => self.hc_channel_send(a0 as u32, a1, a2 as usize, a3, _a4 as usize),
            HC_CHANNEL_RECV => self.hc_channel_recv(a0 as u32, a1, a2 as usize, a3, _a4 as usize),
            HC_CHANNEL_WAIT => self.hc_channel_wait(a0, a1 as usize),
            HC_SHM_CREATE => self.hc_shm_create(a0 as usize),
            HC_SHM_MAP => self.hc_shm_map(vm, a0 as u32, a1, a2 as usize),
            HC_SHM_UNMAP => self.hc_shm_unmap(vm, a0, a1 as usize),
            HC_SIGNAL_CREATE => self.hc_signal_create(),
            HC_SIGNAL_NOTIFY => self.hc_signal_notify(a0 as u32),
            HC_SIGNAL_WAIT => self.hc_signal_wait(a0 as u32),
            _ => {
                eprintln!("unknown hypercall: {}", nr);
                HC_ERR_INVALID
            }
        }
    }

    /// channel_create() -> (id_0, id_1) packed as (id_0 | (id_1 << 32))
    fn hc_channel_create(&mut self) -> i64 {
        // Create two endpoints. Each holds a reference to its peer.
        // We need to create both first to know IDs, then set peer fields.
        let id0 = self.handles.insert(Resource::Channel(Channel::new(0)));
        let id1 = self.handles.insert(Resource::Channel(Channel::new(id0)));
        // Now fix up id0's peer
        if let Some(Resource::Channel(ch)) = self.handles.get_mut(id0) {
            ch.peer = id1;
        }
        (id0 as i64) | ((id1 as i64) << 32)
    }

    /// channel_send(channel_id, data, data_len, handles_ptr, handle_count)
    fn hc_channel_send(
        &mut self,
        channel_id: u32,
        data_ptr: u64,
        data_len: usize,
        handles_ptr: u64,
        handle_count: usize,
    ) -> i64 {
        // Read data from guest memory
        let data = match self.guest_slice(data_ptr, data_len) {
            Some(s) => s.to_vec(),
            None => return HC_ERR_INVALID,
        };

        // Read handles from guest memory
        let mut handles = Vec::with_capacity(handle_count);
        if handle_count > 0 {
            let handle_bytes = match self.guest_slice(handles_ptr, handle_count * 4) {
                Some(s) => s,
                None => return HC_ERR_INVALID,
            };
            for i in 0..handle_count {
                let h = u32::from_le_bytes(handle_bytes[i * 4..(i + 1) * 4].try_into().unwrap());
                handles.push(h);
            }
        }

        // Find the peer endpoint
        let peer_id = match self.handles.get(channel_id) {
            Some(Resource::Channel(ch)) => ch.peer,
            _ => return HC_ERR_NOT_FOUND,
        };

        // Push message into peer's queue
        let msg = Message { data, handles };
        match self.handles.get_mut(peer_id) {
            Some(Resource::Channel(peer_ch)) => {
                peer_ch.queue.push_back(msg);
                HC_OK
            }
            _ => HC_ERR_NOT_FOUND,
        }
    }

    /// channel_recv(channel_id, buf, buf_len, handles_buf, handle_count) -> msg_len
    fn hc_channel_recv(
        &mut self,
        channel_id: u32,
        buf_ptr: u64,
        buf_len: usize,
        handles_ptr: u64,
        handle_count: usize,
    ) -> i64 {
        let msg = match self.handles.get_mut(channel_id) {
            Some(Resource::Channel(ch)) => match ch.queue.pop_front() {
                Some(msg) => msg,
                None => return HC_ERR_NO_DATA,
            },
            _ => return HC_ERR_NOT_FOUND,
        };

        if msg.data.len() > buf_len {
            return HC_ERR_TOO_LARGE;
        }

        // Write data to guest buffer
        if let Some(buf) = self.guest_slice_mut(buf_ptr, msg.data.len()) {
            buf.copy_from_slice(&msg.data);
        } else {
            return HC_ERR_INVALID;
        }

        // Write handles to guest buffer
        let handles_to_copy = msg.handles.len().min(handle_count);
        if handles_to_copy > 0 {
            if let Some(hbuf) = self.guest_slice_mut(handles_ptr, handles_to_copy * 4) {
                for (i, h) in msg.handles[..handles_to_copy].iter().enumerate() {
                    hbuf[i * 4..(i + 1) * 4].copy_from_slice(&h.to_le_bytes());
                }
            } else {
                return HC_ERR_INVALID;
            }
        }

        msg.data.len() as i64
    }

    /// channel_wait(channel_ids_ptr, count) -> ready_mask
    fn hc_channel_wait(&self, ids_ptr: u64, count: usize) -> i64 {
        if count > 64 {
            return HC_ERR_INVALID;
        }
        let id_bytes = match self.guest_slice(ids_ptr, count * 4) {
            Some(s) => s,
            None => return HC_ERR_INVALID,
        };

        let mut mask: u64 = 0;
        for i in 0..count {
            let id = u32::from_le_bytes(id_bytes[i * 4..(i + 1) * 4].try_into().unwrap());
            if let Some(Resource::Channel(ch)) = self.handles.get(id) {
                if !ch.queue.is_empty() {
                    mask |= 1 << i;
                }
            }
        }
        mask as i64
    }

    /// shm_create(size) -> handle
    fn hc_shm_create(&mut self, size: usize) -> i64 {
        if size == 0 {
            return HC_ERR_INVALID;
        }
        // Round up to page size
        let page_size = 4096;
        let size = (size + page_size - 1) & !(page_size - 1);

        let ptr = unsafe {
            libc::mmap(
                ptr::null_mut(),
                size,
                libc::PROT_READ | libc::PROT_WRITE,
                libc::MAP_ANONYMOUS | libc::MAP_PRIVATE,
                -1,
                0,
            )
        };
        if ptr == libc::MAP_FAILED {
            return HC_ERR_INVALID;
        }

        let shm = SharedMemory::new(ptr as *mut u8, size);
        let id = self.handles.insert(Resource::SharedMemory(shm));
        id as i64
    }

    /// shm_map(handle, offset, len) -> guest_addr
    fn hc_shm_map<V: Vm>(&mut self, vm: &V, handle: u32, offset: u64, len: usize) -> i64 {
        // Validate the handle and get the host pointer
        let (host_ptr, shm_size) = match self.handles.get(handle) {
            Some(Resource::SharedMemory(shm)) => (shm.host_ptr, shm.size),
            _ => return HC_ERR_NOT_FOUND,
        };

        if offset as usize + len > shm_size {
            return HC_ERR_INVALID;
        }

        // Allocate a guest physical address
        let guest_addr = self.next_guest_addr;
        // Align to page boundary
        let page_size = 4096u64;
        let aligned_len = ((len as u64) + page_size - 1) & !(page_size - 1);
        self.next_guest_addr += aligned_len;

        let slot = self.next_slot;
        self.next_slot += 1;

        let mapped_host_ptr = unsafe { host_ptr.add(offset as usize) };
        if let Err(e) = vm.add_memory_region(slot, guest_addr, mapped_host_ptr, len) {
            eprintln!("failed to map shared memory: {}", e);
            return HC_ERR_INVALID;
        }

        // Record the mapping
        if let Some(Resource::SharedMemory(shm)) = self.handles.get_mut(handle) {
            shm.guest_slot = Some(slot);
            shm.guest_addr = Some(guest_addr);
        }

        guest_addr as i64
    }

    /// shm_unmap(guest_addr, len)
    fn hc_shm_unmap<V: Vm>(&mut self, vm: &V, guest_addr: u64, _len: usize) -> i64 {
        // Find the handle with this guest_addr
        // We need to scan since we don't have a reverse mapping
        let mut found_slot = None;
        for (_id, res) in self.handles.handles_iter() {
            if let Resource::SharedMemory(shm) = res {
                if shm.guest_addr == Some(guest_addr) {
                    found_slot = shm.guest_slot;
                    break;
                }
            }
        }

        if let Some(slot) = found_slot {
            if let Err(e) = vm.remove_memory_region(slot) {
                eprintln!("failed to unmap shared memory: {}", e);
                return HC_ERR_INVALID;
            }
            HC_OK
        } else {
            HC_ERR_NOT_FOUND
        }
    }

    /// signal_create() -> handle
    fn hc_signal_create(&mut self) -> i64 {
        let id = self.handles.insert(Resource::Signal(Signal::new()));
        id as i64
    }

    /// signal_notify(handle)
    fn hc_signal_notify(&mut self, handle: u32) -> i64 {
        match self.handles.get_mut(handle) {
            Some(Resource::Signal(sig)) => {
                sig.signaled = true;
                HC_OK
            }
            _ => HC_ERR_NOT_FOUND,
        }
    }

    /// signal_wait(handle)
    fn hc_signal_wait(&mut self, handle: u32) -> i64 {
        match self.handles.get_mut(handle) {
            Some(Resource::Signal(sig)) => {
                if sig.signaled {
                    sig.signaled = false;
                    HC_OK
                } else {
                    HC_ERR_NO_DATA
                }
            }
            _ => HC_ERR_NOT_FOUND,
        }
    }
}

/// Minimal ELF64 loader. Loads PT_LOAD segments into guest memory and returns the entry point.
fn load_elf(elf_data: &[u8], guest_mem: &mut [u8]) -> Result<u64> {
    // ELF64 header constants
    const EI_MAG: [u8; 4] = [0x7f, b'E', b'L', b'F'];
    const PT_LOAD: u32 = 1;

    if elf_data.len() < 64 || elf_data[..4] != EI_MAG {
        bail!("not a valid ELF file");
    }
    if elf_data[4] != 2 {
        bail!("not a 64-bit ELF");
    }

    let entry = u64::from_le_bytes(elf_data[24..32].try_into().unwrap());
    let phoff = u64::from_le_bytes(elf_data[32..40].try_into().unwrap()) as usize;
    let phentsize = u16::from_le_bytes(elf_data[54..56].try_into().unwrap()) as usize;
    let phnum = u16::from_le_bytes(elf_data[56..58].try_into().unwrap()) as usize;

    for i in 0..phnum {
        let off = phoff + i * phentsize;
        let phdr = &elf_data[off..off + phentsize];

        let p_type = u32::from_le_bytes(phdr[0..4].try_into().unwrap());
        if p_type != PT_LOAD {
            continue;
        }

        let p_offset = u64::from_le_bytes(phdr[8..16].try_into().unwrap()) as usize;
        let p_paddr = u64::from_le_bytes(phdr[24..32].try_into().unwrap()) as usize;
        let p_filesz = u64::from_le_bytes(phdr[32..40].try_into().unwrap()) as usize;
        let p_memsz = u64::from_le_bytes(phdr[40..48].try_into().unwrap()) as usize;

        if p_paddr + p_memsz > guest_mem.len() {
            bail!(
                "ELF segment at {:#x} (size {:#x}) exceeds guest memory",
                p_paddr,
                p_memsz
            );
        }

        // Copy file data
        guest_mem[p_paddr..p_paddr + p_filesz]
            .copy_from_slice(&elf_data[p_offset..p_offset + p_filesz]);
        // Zero BSS (memsz > filesz)
        if p_memsz > p_filesz {
            guest_mem[p_paddr + p_filesz..p_paddr + p_memsz].fill(0);
        }
    }

    Ok(entry)
}

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 2 {
        eprintln!("usage: {} <guest-binary>", args[0]);
        std::process::exit(1);
    }

    let guest_binary = fs::read(&args[1]).context("failed to read guest binary")?;

    // Allocate guest memory
    let guest_mem = unsafe {
        libc::mmap(
            ptr::null_mut(),
            GUEST_MEM_SIZE,
            libc::PROT_READ | libc::PROT_WRITE,
            libc::MAP_ANONYMOUS | libc::MAP_PRIVATE,
            -1,
            0,
        )
    };
    if guest_mem == libc::MAP_FAILED {
        bail!("failed to mmap guest memory");
    }
    let guest_mem = guest_mem as *mut u8;
    let mem_slice =
        unsafe { std::slice::from_raw_parts_mut(guest_mem, GUEST_MEM_SIZE) };

    // Set up page tables and GDT in guest memory
    crate::x86_64::setup_page_tables(mem_slice);
    let gdt = crate::x86_64::setup_gdt(mem_slice);

    // Load guest ELF binary
    let entry = load_elf(&guest_binary, mem_slice)?;

    // Create KVM VM
    let kvm = KvmHypervisor::new().context("failed to create KVM hypervisor")?;
    let vm = kvm.create_vm().context("failed to create VM")?;

    // x86_64 KVM initialization (TSS, IRQ chip)
    vm.init_x86_64().context("failed to init x86_64 VM")?;

    // Register guest memory
    vm.add_memory_region(0, 0, guest_mem, GUEST_MEM_SIZE)
        .context("failed to add memory region")?;

    // Create vCPU
    let mut vcpu = vm.create_vcpu(0).context("failed to create vCPU")?;

    // Set up special registers for long mode
    let sregs = crate::x86_64::setup_long_mode_sregs(&gdt);
    vcpu.set_sregs(&sregs).context("failed to set sregs")?;

    // Set up initial registers
    let regs = crate::x86_64::setup_initial_regs(entry, STACK_TOP);
    vcpu.set_regs(&regs).context("failed to set regs")?;

    // VMM state for hypercall handling
    let mut state = VmState::new(guest_mem, GUEST_MEM_SIZE);

    // Run loop
    loop {
        let exit = vcpu.run().context("vCPU run failed")?;
        match exit {
            VcpuExit::Mmio {
                addr,
                is_write: true,
                ..
            } if addr == HYPERCALL_ADDR => {
                let regs = vcpu.get_regs()?;
                let ret = state.dispatch(
                    &vm, regs.rax, regs.rdi, regs.rsi, regs.rdx, regs.r10, regs.r8, regs.r9,
                );
                vcpu.set_regs(&crate::x86_64::Regs {
                    rax: ret as u64,
                    ..regs
                })?;
            }
            VcpuExit::Hlt => {
                break;
            }
            VcpuExit::Shutdown => {
                break;
            }
            other => {
                let regs = vcpu.get_regs()?;
                bail!("unexpected exit: {:?} at rip={:#x}", other, regs.rip);
            }
        }
    }

    Ok(())
}
