use core::arch::asm;

const HYPERCALL_ADDR: u64 = 0x400_0000;

const HC_EXIT: u64 = 0;
const HC_CHANNEL_CREATE: u64 = 1;
const HC_CHANNEL_SEND: u64 = 2;
const HC_CHANNEL_RECV: u64 = 3;
const HC_CHANNEL_WAIT: u64 = 4;
const HC_SHM_CREATE: u64 = 5;
const HC_SHM_MAP: u64 = 6;
const HC_SHM_UNMAP: u64 = 7;
const HC_SIGNAL_CREATE: u64 = 8;
const HC_SIGNAL_NOTIFY: u64 = 9;
const HC_SIGNAL_WAIT: u64 = 10;

/// Issue a hypercall via MMIO store.
/// ABI: rax=nr, rdi=a0, rsi=a1, rdx=a2, r10=a3, r8=a4, r9=a5
/// The store to HYPERCALL_ADDR triggers KVM_EXIT_MMIO.
/// Return value is in rax after the VMM sets it.
#[inline(always)]
unsafe fn hypercall(nr: u64, a0: u64, a1: u64, a2: u64, a3: u64, a4: u64, a5: u64) -> i64 {
    let ret: i64;
    asm!(
        "mov [{mmio}], rax",
        mmio = in(reg) HYPERCALL_ADDR,
        inlateout("rax") nr => ret,
        in("rdi") a0,
        in("rsi") a1,
        in("rdx") a2,
        in("r10") a3,
        in("r8") a4,
        in("r9") a5,
        options(nostack, preserves_flags),
    );
    ret
}

pub fn exit(code: i64) -> ! {
    unsafe {
        hypercall(HC_EXIT, code as u64, 0, 0, 0, 0, 0);
    }
    loop {}
}

/// Returns (id0, id1) as a pair of handle IDs.
pub fn channel_create() -> (u32, u32) {
    let ret = unsafe { hypercall(HC_CHANNEL_CREATE, 0, 0, 0, 0, 0, 0) };
    let id0 = (ret as u64 & 0xFFFF_FFFF) as u32;
    let id1 = ((ret as u64) >> 32) as u32;
    (id0, id1)
}

pub fn channel_send(
    channel_id: u32,
    data: *const u8,
    data_len: usize,
    handles: *const u32,
    handle_count: usize,
) -> i64 {
    unsafe {
        hypercall(
            HC_CHANNEL_SEND,
            channel_id as u64,
            data as u64,
            data_len as u64,
            handles as u64,
            handle_count as u64,
            0,
        )
    }
}

pub fn channel_recv(
    channel_id: u32,
    buf: *mut u8,
    buf_len: usize,
    handles: *mut u32,
    handle_count: usize,
) -> i64 {
    unsafe {
        hypercall(
            HC_CHANNEL_RECV,
            channel_id as u64,
            buf as u64,
            buf_len as u64,
            handles as u64,
            handle_count as u64,
            0,
        )
    }
}

pub fn channel_wait(ids: *const u32, count: usize) -> i64 {
    unsafe { hypercall(HC_CHANNEL_WAIT, ids as u64, count as u64, 0, 0, 0, 0) }
}

pub fn shm_create(size: usize) -> u32 {
    let ret = unsafe { hypercall(HC_SHM_CREATE, size as u64, 0, 0, 0, 0, 0) };
    ret as u32
}

pub fn shm_map(handle: u32, offset: u64, len: usize) -> u64 {
    let ret = unsafe { hypercall(HC_SHM_MAP, handle as u64, offset, len as u64, 0, 0, 0) };
    ret as u64
}

pub fn shm_unmap(addr: u64, len: usize) -> i64 {
    unsafe { hypercall(HC_SHM_UNMAP, addr, len as u64, 0, 0, 0, 0) }
}

pub fn signal_create() -> u32 {
    let ret = unsafe { hypercall(HC_SIGNAL_CREATE, 0, 0, 0, 0, 0, 0) };
    ret as u32
}

pub fn signal_notify(handle: u32) -> i64 {
    unsafe { hypercall(HC_SIGNAL_NOTIFY, handle as u64, 0, 0, 0, 0, 0) }
}

pub fn signal_wait(handle: u32) -> i64 {
    unsafe { hypercall(HC_SIGNAL_WAIT, handle as u64, 0, 0, 0, 0, 0) }
}
