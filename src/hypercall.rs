// Hypercall numbers.
pub const HC_EXIT: u64 = 0;
pub const HC_CHANNEL_CREATE: u64 = 1;
pub const HC_CHANNEL_SEND: u64 = 2;
pub const HC_CHANNEL_RECV: u64 = 3;
pub const HC_CHANNEL_WAIT: u64 = 4;
pub const HC_SHM_CREATE: u64 = 5;
pub const HC_SHM_MAP: u64 = 6;
pub const HC_SHM_UNMAP: u64 = 7;
pub const HC_SIGNAL_CREATE: u64 = 8;
pub const HC_SIGNAL_NOTIFY: u64 = 9;
pub const HC_SIGNAL_WAIT: u64 = 10;

// Error codes returned to guest.
pub const HC_OK: i64 = 0;
pub const HC_ERR_INVALID: i64 = -1;
pub const HC_ERR_NOT_FOUND: i64 = -2;
pub const HC_ERR_NO_DATA: i64 = -3;
pub const HC_ERR_TOO_LARGE: i64 = -4;
