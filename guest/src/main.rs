#![no_std]
#![no_main]

mod hypercall;

use core::panic::PanicInfo;
use hypercall::*;

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    exit(1);
}

#[no_mangle]
pub extern "C" fn _start() -> ! {
    test_channels();
    test_shared_memory();
    test_signals();

    // All tests passed
    exit(0);
}

fn test_channels() {
    // Create a channel pair
    let (ch0, ch1) = channel_create();
    assert_ne(ch0 as i64, 0, "channel_create ch0");
    assert_ne(ch1 as i64, 0, "channel_create ch1");

    // Send a message from ch0 to ch1
    let msg = b"hello";
    let ret = channel_send(ch0, msg.as_ptr(), msg.len(), core::ptr::null(), 0);
    assert_eq(ret, 0, "channel_send");

    // Wait on ch1 — should have data ready
    let ids = [ch1];
    let mask = channel_wait(ids.as_ptr(), 1);
    assert_eq(mask, 1, "channel_wait ready");

    // Recv on ch1
    let mut buf = [0u8; 64];
    let len = channel_recv(ch1, buf.as_mut_ptr(), buf.len(), core::ptr::null_mut(), 0);
    assert_eq(len, 5, "channel_recv len");
    assert_eq(buf[0] as i64, b'h' as i64, "channel_recv data[0]");
    assert_eq(buf[1] as i64, b'e' as i64, "channel_recv data[1]");
    assert_eq(buf[4] as i64, b'o' as i64, "channel_recv data[4]");

    // Recv again should return no data
    let len = channel_recv(ch1, buf.as_mut_ptr(), buf.len(), core::ptr::null_mut(), 0);
    assert_eq(len, -3, "channel_recv empty");

    // Test sending with handles
    let (ch2, ch3) = channel_create();
    let handles = [ch2];
    let ret = channel_send(ch0, msg.as_ptr(), msg.len(), handles.as_ptr(), 1);
    assert_eq(ret, 0, "channel_send with handle");

    let mut recv_handles = [0u32; 4];
    let len = channel_recv(
        ch1,
        buf.as_mut_ptr(),
        buf.len(),
        recv_handles.as_mut_ptr(),
        1,
    );
    assert_eq(len, 5, "channel_recv with handle len");
    assert_eq(recv_handles[0] as i64, ch2 as i64, "channel_recv handle");

    // Wait on ch1 with no data
    let mask = channel_wait(ids.as_ptr(), 1);
    assert_eq(mask, 0, "channel_wait not ready");

    // Cleanup: test with ch3
    let _ = ch3;
}

fn test_shared_memory() {
    // Create shared memory (4096 bytes)
    let handle = shm_create(4096);
    assert_gt(handle as i64, 0, "shm_create");

    // Map it into guest address space
    let addr = shm_map(handle, 0, 4096);
    assert_gt(addr as i64, 0, "shm_map");

    // Write to shared memory
    let ptr = addr as *mut u32;
    unsafe {
        core::ptr::write_volatile(ptr, 0xDEAD_BEEF);
    }

    // Read back
    let val = unsafe { core::ptr::read_volatile(ptr) };
    assert_eq(val as i64, 0xDEAD_BEEF_u32 as i64, "shm read back");

    // Unmap
    let ret = shm_unmap(addr, 4096);
    assert_eq(ret, 0, "shm_unmap");
}

fn test_signals() {
    // Create a signal
    let handle = signal_create();
    assert_gt(handle as i64, 0, "signal_create");

    // Wait should return no data (not signaled)
    let ret = signal_wait(handle);
    assert_eq(ret, -3, "signal_wait not signaled");

    // Notify
    let ret = signal_notify(handle);
    assert_eq(ret, 0, "signal_notify");

    // Wait should now succeed
    let ret = signal_wait(handle);
    assert_eq(ret, 0, "signal_wait signaled");

    // Wait again should return no data (auto-clear)
    let ret = signal_wait(handle);
    assert_eq(ret, -3, "signal_wait after clear");
}

// Simple assertion helpers that don't depend on formatting

fn assert_eq(a: i64, b: i64, _msg: &str) {
    if a != b {
        exit(1);
    }
}

fn assert_ne(a: i64, b: i64, _msg: &str) {
    if a == b {
        exit(1);
    }
}

fn assert_gt(a: i64, b: i64, _msg: &str) {
    if a <= b {
        exit(1);
    }
}
