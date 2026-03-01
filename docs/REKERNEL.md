# Rekernel Design

The rekernel is a minimal guest OS kernel that runs inside the Revisor VM. It provides
process isolation via hardware page tables, a syscall interface for user-mode programs,
and a validated proxy for host-facing hypercalls. It is not a general-purpose OS — it has
no VFS, no networking, no device drivers beyond the hypercall MMIO interface.

## Architecture Overview

```
 User Process A (ring 3)     User Process B (ring 3)
 ┌───────────────────────┐   ┌───────────────────────┐
 │ renderer              │   │ JS engine             │
 │ (host hypercalls OK)  │   │ (no host hypercalls)  │
 └─────────┬─────────────┘   └─────────┬─────────────┘
           │ SYSCALL                    │ SYSCALL
 ══════════╪════════════════════════════╪══════════════
           │         Rekernel (ring 0)  │
           │  ┌─────────────────────────┤
           │  │  syscall dispatch       │
           │  │  page table mgmt        │
           │  │  scheduler              │
           │  │  physical page alloc    │
           │  └────────┬────────────────┘
           │           │ MMIO store to 0x400_0000
 ══════════╪═══════════╪══════════════════════════════
           │           │        VMM (host)
           │           └──► hypercall handler
           └────────────────────────────────────────►
```

User processes enter the kernel via `SYSCALL`. The rekernel handles memory management,
threading, and futex entirely in-guest (no VM exit). Host-facing hypercalls cause a single
VM exit: the kernel validates the request, stores to the MMIO address, the VMM handles it,
and control returns.

## Boot Sequence

The VMM loads the rekernel as an ELF binary at physical address 0x10_0000 (1MB), sets up
identity-mapped page tables for the first 1GB, configures long mode, and jumps to the
rekernel entry point at ring 0.

The rekernel then:

1. **Initialize GDT**: four segments — null, kernel code (ring 0, L=1), kernel data,
   user code (ring 3, L=1), user data. Plus a TSS descriptor.
2. **Initialize TSS**: set RSP0 to the boot kernel stack. Updated on every context switch
   to point to the current thread's kernel stack.
3. **Initialize IDT**: handlers for page fault (#PF), general protection (#GP), double
   fault (#DF), timer interrupt, and the syscall vector (though SYSCALL/SYSRET is
   preferred over INT-based dispatch).
4. **Configure SYSCALL/SYSRET MSRs**: write STAR (segment selectors), LSTAR (syscall
   entry point), SFMASK (RFLAGS mask — disable interrupts on entry).
5. **Set up kernel page tables**: create a new PML4 with the kernel direct-mapped in the
   upper half and switch CR3 away from the boot identity map.
6. **Initialize physical page allocator**: read total memory size from boot info, mark
   kernel pages as used, rest as free.
7. **Load user programs**: read the boot info table placed by the VMM, load each ELF
   into a new address space, create the initial process and thread for each.
8. **Start scheduler**: context-switch to the first runnable thread via SYSRET.

### Boot Info

The VMM places a boot info table at physical address 0x5000 before starting the guest:

```
struct BootInfo {
    magic: u64,              // 0x524556_424F4F54 ("REVBOOT")
    phys_mem_size: u64,      // total guest physical memory in bytes
    num_programs: u32,
    _pad: u32,
    programs: [ProgramInfo],
}

struct ProgramInfo {
    phys_addr: u64,          // physical address of ELF data
    size: u64,               // ELF data size in bytes
    flags: u32,              // PROG_ALLOW_HYPERCALLS = 1
    _pad: u32,
}
```

The VMM loads the rekernel at 1MB, then loads user ELFs at subsequent aligned addresses
(e.g., 2MB, 3MB, ...), records their positions in the boot info table, and starts the
guest.

## Memory Layout

### Guest Physical Memory

```
0x0000_0000 - 0x0000_0FFF   Reserved
0x0000_1000 - 0x0000_3FFF   Boot page tables (reclaimable after kernel sets up its own)
0x0000_4000 - 0x0000_4FFF   Boot GDT (reclaimable)
0x0000_5000 - 0x0000_5FFF   Boot info table (written by VMM)
0x0000_6000 - 0x000F_FFFF   Available for kernel structures
0x0010_0000 - 0x001F_FFFF   Rekernel code + data (loaded by VMM)
0x0020_0000 - ...            User ELF images (loaded by VMM, reclaimable after loading)
    ...     - 0x03FF_FFFF   Free physical pages
0x0400_0000                  Hypercall MMIO page (not backed by RAM)
0x0400_1000+                 Shared memory regions (mapped dynamically by VMM)
```

Physical memory above 0x0400_0000 is managed by the VMM for shared memory mappings and
should not be touched by the rekernel's page allocator.

### Virtual Address Space

Each process has its own PML4. The upper half is shared across all processes (kernel
mapping). The lower half is per-process.

```
Lower half (user, per-process):
0x0000_0000_0040_0000   User code base (ELF loaded here)
        ...              Heap (grows up via mmap)
0x0000_7FFF_FFFF_0000   Default stack top (grows down)

Upper half (kernel, shared):
0xFFFF_8000_0000_0000   Direct map of all physical memory
                        (phys addr X accessible at 0xFFFF_8000_0000_0000 + X)
0xFFFF_FFFF_8010_0000   Kernel code/data (mapped to phys 0x10_0000)
```

The kernel direct map uses 2MB pages for the first 1GB (matching the boot identity map).
This lets the kernel access any physical page by adding the direct-map base offset.

User pages use 4KB granularity for fine-grained protection.

## Syscall Interface

Syscalls use the `SYSCALL` instruction. ABI matches the Linux convention for register
usage:

- `rax`: syscall number (input), return value (output)
- `rdi`, `rsi`, `rdx`, `r10`, `r8`, `r9`: arguments 0-5

Negative return values indicate errors (e.g., -ENOMEM, -EINVAL, -EFAULT, -EPERM, -EAGAIN).

### Process Lifecycle

| # | Name | Signature | Description |
|---|------|-----------|-------------|
| 0 | exit | `exit(code: i32) -> !` | Terminate current process and all its threads. |
| 1 | getpid | `getpid() -> u32` | Return current process ID. |
| 2 | gettid | `gettid() -> u32` | Return current thread ID. |

### Memory Management

| # | Name | Signature | Description |
|---|------|-----------|-------------|
| 10 | mmap | `mmap(addr: u64, len: u64, prot: u32, flags: u32) -> u64` | Map anonymous memory. |
| 11 | munmap | `munmap(addr: u64, len: u64) -> i64` | Unmap memory region. |
| 12 | mprotect | `mprotect(addr: u64, len: u64, prot: u32) -> i64` | Change page protection. |

**prot flags**: `PROT_READ = 1`, `PROT_WRITE = 2`, `PROT_EXEC = 4`.

**mmap flags**: `MAP_ANONYMOUS = 1`, `MAP_FIXED = 2`, `MAP_SHARED = 4`.

`mmap` with `MAP_ANONYMOUS` allocates zero-filled pages (demand-paged: physical pages
allocated on first access via page fault handler). `addr` is a hint unless `MAP_FIXED`
is set. Returns the mapped virtual address, or a negative error.

`MAP_SHARED` creates a mapping backed by a shared memory object that can be mapped into
multiple processes. See in-guest IPC below.

### Threading

| # | Name | Signature | Description |
|---|------|-----------|-------------|
| 20 | thread_create | `thread_create(entry: u64, stack: u64, arg: u64) -> i64` | Create thread in current process. |
| 21 | thread_exit | `thread_exit(code: i32) -> !` | Exit current thread. |
| 22 | futex_wait | `futex_wait(addr: u64, expected: u32) -> i64` | Sleep if `*addr == expected`. |
| 23 | futex_wake | `futex_wake(addr: u64, count: u32) -> i64` | Wake up to `count` waiters. |
| 24 | yield | `yield() -> i64` | Yield CPU to scheduler. |
| 25 | set_tls | `set_tls(addr: u64) -> i64` | Set FS base for thread-local storage. |

`thread_create` creates a new thread sharing the same address space. The kernel allocates
a kernel-mode stack for the new thread. The thread starts at `entry` with `rdi = arg` and
`rsp = stack`. Returns the thread ID, or a negative error.

`futex_wait` atomically checks that the 32-bit value at `addr` equals `expected` and puts
the thread to sleep. Returns 0 when woken, -EAGAIN if the value didn't match.

`futex_wake` wakes up to `count` threads sleeping on `addr`. Returns the number woken.

### Host Hypercall Proxy

| # | Name | Signature | Description |
|---|------|-----------|-------------|
| 30 | hypercall | `hypercall(nr: u64, a0-a4: u64) -> i64` | Forward hypercall to VMM. |

The kernel checks that the calling process has the `ALLOW_HYPERCALLS` flag (set at load
time from boot info). If not, returns -EPERM. Otherwise, writes the hypercall to the MMIO
address and returns the result.

This single syscall replaces 10 individual hypercall-specific syscalls. User-space wrapper
functions (in a guest libc) provide typed interfaces:

```rust
fn channel_create() -> (u32, u32) {
    let r = syscall(SYS_HYPERCALL, HC_CHANNEL_CREATE, 0, 0, 0, 0, 0);
    (r as u32, (r >> 32) as u32)
}
```

### In-Guest Shared Memory

| # | Name | Signature | Description |
|---|------|-----------|-------------|
| 40 | shmem_create | `shmem_create(size: u64) -> i64` | Create shared memory object. Returns handle. |
| 41 | shmem_map | `shmem_map(handle: u32, offset: u64, len: u64, prot: u32) -> u64` | Map shared memory into current process. |

In-guest shared memory is distinct from host shared memory (which uses hypercalls).
`shmem_create` allocates physical pages for a shared region. `shmem_map` maps those
pages into the calling process's address space. Multiple processes can map the same
handle, enabling zero-copy data sharing within the guest.

Combined with `futex_wait`/`futex_wake` on addresses within the shared region, this
provides efficient inter-process communication without VM exits.

### Debug

| # | Name | Signature | Description |
|---|------|-----------|-------------|
| 50 | debug_write | `debug_write(buf: u64, len: u64) -> i64` | Write to debug console. |
| 51 | clock_gettime | `clock_gettime() -> u64` | Return nanoseconds since boot (RDTSC-based). |

`debug_write` is forwarded to the VMM as a console write hypercall (requires a new
hypercall `HC_WRITE = 11`). Useful for printf-style debugging during development.

## Process Model

A **process** has:
- A unique PID (u32)
- A PML4 (page table root) — its own virtual address space
- A list of threads
- Permission flags (e.g., `ALLOW_HYPERCALLS`)
- A set of shmem handle mappings

A **thread** has:
- A unique TID (u32)
- A saved register state (GPRs, RIP, RSP, RFLAGS, FS base)
- A kernel stack (allocated by the kernel, used during syscalls/interrupts)
- A scheduler state (running, ready, blocked)
- An optional futex wait address

Processes are created by the kernel during boot from the boot info program list. There
is no `fork` or `exec` — the set of processes is static after boot. Threads are created
dynamically via `thread_create`.

## Scheduler

Round-robin across all runnable threads, single vCPU.

The LAPIC timer fires periodically (e.g., every 10ms) to preempt the running thread.
On timer interrupt:

1. Save current thread's register state to its thread control block.
2. Pick next runnable thread (round-robin).
3. If switching processes (different PID), update CR3.
4. Update TSS.RSP0 to the new thread's kernel stack.
5. Restore new thread's register state.
6. IRET to resume execution.

Threads blocked on `futex_wait` are removed from the run queue. `futex_wake` moves them
back.

Multi-vCPU support is deferred — the initial implementation uses a single vCPU with
cooperative and timer-preempted scheduling.

## Page Table Management

The kernel maintains per-process page tables. Operations:

- **map_page(pml4, virt, phys, flags)**: Walk/allocate PML4→PDPT→PD→PT entries, set
  the leaf PTE to `phys | flags`. Flags include present, writable, user, NX.
- **unmap_page(pml4, virt)**: Clear the leaf PTE. Free the physical page if it was
  allocated by the kernel.
- **page fault handler**: on #PF for a demand-paged region, allocate a physical page,
  zero it, and map it. For invalid accesses, kill the process.

Kernel pages (upper half) are marked supervisor-only (user bit clear). User pages (lower
half) have the user bit set. This prevents user code from accessing kernel memory.

The kernel never maps user memory as executable + writable simultaneously (W^X).

## Physical Page Allocator

A bitmap allocator tracking which 4KB pages are free/used.

```
struct PageAllocator {
    bitmap: &mut [u64],     // 1 bit per 4KB page, stored in kernel BSS or direct map
    total_pages: usize,
    free_pages: usize,
}
```

On boot, mark pages 0 through end-of-kernel as used. Mark pages from end-of-kernel
through `phys_mem_size / 4096` as free. Pages above `phys_mem_size` don't exist. Pages
at/above 0x0400_0000 (hypercall region) are reserved.

## Interrupt Handling

### IDT Entries

| Vector | Name | Handler |
|--------|------|---------|
| 0 | #DE | Divide error — kill process |
| 6 | #UD | Invalid opcode — kill process |
| 8 | #DF | Double fault — panic |
| 13 | #GP | General protection — kill process |
| 14 | #PF | Page fault — demand page or kill |
| 32 | Timer | LAPIC timer — preempt and schedule |

All other vectors: unexpected interrupt — panic.

### Syscall Entry

The `SYSCALL` instruction jumps to the address in the LSTAR MSR. The entry point:

1. Swap to kernel stack: `swapgs`, load RSP from the per-CPU kernel stack pointer
   (stored via GS base or TSS).
2. Save user registers (RCX = return RIP, R11 = return RFLAGS, plus GPRs).
3. Dispatch based on RAX (syscall number).
4. Store return value in RAX.
5. Restore user registers.
6. `SYSRET` to return to user mode.

SFMASK is set to mask IF (interrupt flag) so interrupts are disabled during the
kernel entry sequence until the kernel stack is set up.

## Implementation Plan

### Step 1: Kernel boot and serial output
- Entry point in assembly: set up stack, call Rust `kmain`.
- Set up GDT with kernel/user segments and TSS.
- Set up minimal IDT (double fault, GP fault).
- Add `HC_WRITE` hypercall for console output, verify with "hello world".
- **Verify**: rekernel boots and prints to host console.

### Step 2: Physical page allocator and kernel page tables
- Implement bitmap page allocator.
- Build kernel PML4 with direct map of physical memory in upper half.
- Map kernel code/data.
- Switch CR3 from boot page tables to kernel page tables.
- **Verify**: kernel runs with its own page tables, can allocate/free pages.

### Step 3: User mode and syscalls
- Configure SYSCALL/SYSRET MSRs (STAR, LSTAR, SFMASK).
- Implement syscall entry/exit (save/restore registers, stack switch).
- ELF loader: parse program headers, create user page table, map segments.
- Load a minimal user binary (embedded or from boot info), switch to ring 3.
- Implement `exit` syscall.
- **Verify**: user program runs and exits cleanly.

### Step 4: Memory management syscalls
- Implement `mmap` (anonymous, demand-paged).
- Implement page fault handler for demand paging.
- Implement `munmap`, `mprotect`.
- **Verify**: user program can malloc/free (via mmap) and use the heap.

### Step 5: Threading and scheduling
- Thread control block, kernel stack allocation.
- `thread_create` syscall.
- Timer interrupt via LAPIC, round-robin scheduler.
- Context switch (save/restore all registers, update TSS.RSP0).
- `futex_wait` / `futex_wake`.
- `set_tls` (write FS base via WRFSBASE or MSR).
- **Verify**: multi-threaded user program with futex synchronization.

### Step 6: Hypercall proxy
- `hypercall` syscall with permission check.
- **Verify**: user program creates channels, sends/receives messages,
  creates/maps shared memory, uses signals — all via syscalls.

### Step 7: Multi-process and in-guest IPC
- Multiple processes with separate PML4s.
- `shmem_create` / `shmem_map` for in-guest shared memory.
- Futex works across processes (keyed on physical address).
- **Verify**: two user processes communicating via shared memory + futex.

## Kernel Source Structure

```
guest/rekernel/
├── Cargo.toml
├── linker.ld           (kernel linked at 0xFFFF_FFFF_8010_0000, loaded at 0x10_0000)
├── src/
│   ├── main.rs         (kmain: boot sequence, init subsystems, start scheduler)
│   ├── boot.S          (entry point: set up stack, call kmain)
│   ├── gdt.rs          (GDT, TSS setup)
│   ├── idt.rs          (IDT setup, interrupt handlers)
│   ├── syscall.rs      (SYSCALL/SYSRET setup, syscall dispatch)
│   ├── page_alloc.rs   (physical page bitmap allocator)
│   ├── paging.rs       (page table create/map/unmap, CR3 switch)
│   ├── process.rs      (process struct, ELF loader, address space setup)
│   ├── thread.rs       (thread struct, kernel stack, context switch)
│   ├── sched.rs        (run queue, round-robin, timer handler)
│   ├── futex.rs        (futex wait/wake, wait queues)
│   ├── shmem.rs        (in-guest shared memory objects)
│   ├── hypercall.rs    (MMIO hypercall proxy, permission check)
│   └── console.rs      (debug_write via HC_WRITE)
```

The rekernel is a `#![no_std]` `#![no_main]` Rust binary targeting
`x86_64-unknown-none`. Unsafe code is confined to: `boot.S` (assembly entry),
`syscall.rs` (register save/restore, SYSRET), `paging.rs` (CR3 writes, page table
manipulation), `thread.rs` (context switch assembly), and `idt.rs` (interrupt
entry/exit).

## VMM Changes Required

The VMM needs minimal changes to support the rekernel:

1. **Boot info**: write the `BootInfo` struct at physical address 0x5000 before starting
   the guest. Load user ELFs into physical memory at addresses recorded in the table.
2. **HC_WRITE hypercall** (nr=11): `write(buf_phys, len)` — read `len` bytes from guest
   physical memory at `buf_phys` and write to host stdout. This is the only new
   hypercall needed.
3. **Memory size**: increase `GUEST_MEM_SIZE` as needed (64MB may be sufficient for
   dwplay; Firefox will need more).

Everything else (channel, shm, signal hypercalls) works unchanged — the rekernel
proxies them transparently.
