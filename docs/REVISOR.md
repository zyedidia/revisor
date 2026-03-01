# Revisor: Virtualized Process Isolation for Browser Security

## Overview

Revisor introduces **virtualized processes** — browser renderer processes that execute
inside lightweight virtual machines, using a guest rekernel to provide pagetable-based
isolation between components that today share an address space. The key insight is that
running a renderer inside a VM allows a guest OS to enforce sub-process isolation (e.g.,
between the JavaScript engine and the rest of the renderer) using hardware pagetables,
without the overhead of cross-process IPC for every DOM access.

Today, browsers isolate renderer processes from the browser chrome using OS-level
sandboxing (seccomp-bpf, namespaces). But within a renderer, the JavaScript engine shares
an address space with layout, painting, and DOM code. A JIT bug in the JS engine gives
an attacker access to all cross-site data in the renderer. Chromium's V8 sandbox and
Firefox's ongoing efforts mitigate this, but fundamentally a single compromised renderer
process still has access to everything in its address space.

Revisor solves this by placing the renderer inside a VM with a purpose-built rekernel.
The rekernel runs the JS engine and the renderer as separate guest processes with
distinct address spaces. Communication between them uses fast in-guest IPC (shared memory
+ futex, no VM exit). Communication with the host browser uses a small hypercall-based
transport layer that maps onto Firefox's existing IPDL protocol framework.

## Architecture

```
HOST                                    GUEST VM
                                   ┌─────────────────────────┐
                                   │  Rekernel (ring 0)       │
browser chrome  ◄─── IPDL ───►    │     ┌─────────┐          │
compositor      ◄─── over ────►    │     │ renderer│ (ring 3) │
networking      ◄─── hypercall ──► │     └────┬────┘          │
                                   │     guest IPC            │
                                   │     ┌────┴────┐          │
                                   │     │JS engine│ (ring 3) │
                                   │     └─────────┘          │
                                   └─────────────────────────┘
```

### Threat Model

- **JS engine exploit** should not be able to read renderer memory (cross-site data,
  cookies, DOM state). Enforced by guest pagetable isolation.
- **Renderer exploit** should not be able to escape to the host. Enforced by the VM
  boundary (VMX/SVM).
- **Defense in depth**: a full compromise chain requires JS engine exploit → guest
  kernel exploit → VM escape — three independent security boundaries.

### Hypercall Interface

The guest communicates with the host through a minimal set of transport-primitive
hypercalls. These are not Linux syscalls and not IPDL-specific — they are generic
message-passing and shared-memory primitives that IPDL's transport layer is built on.

```
// Message passing
channel_send(channel_id, data, data_len, handles[], handle_count)
channel_recv(channel_id, buf, buf_len, handles[], handle_count) -> msg_len
channel_wait(channel_ids[], count, timeout) -> ready_mask
channel_create() -> (id_0, id_1)

// Shared memory
shm_create(size) -> handle
shm_map(handle, offset, len) -> guest_addr
shm_unmap(guest_addr, len)

// Signaling
signal_create() -> handle
signal_notify(handle)
signal_wait(handle, timeout)
```

Hypercalls are issued via MMIO writes to a fixed address. The renderer (ring 3) makes a
guest syscall to the rekernel (ring 0), which validates the request and issues the MMIO
store. The VMM on the host handles the hypercall and translates it into host-side IPDL
operations.

The rekernel mediates hypercall access: the JS engine process is restricted to in-guest
IPC only, while the renderer is the only guest process authorized to make host-facing
hypercalls.

### Guest Rekernel

The rekernel is written in Rust and provides:

- **Virtual memory management**: separate address spaces per guest process, pagetable
  manipulation, page fault handling.
- **Threading and scheduling**: clone-style thread creation, futex, basic round-robin or
  priority scheduling.
- **In-guest IPC**: shared memory regions and futex-based signaling between guest processes
  (renderer ↔ JS engine). No VM exit required.
- **Hypercall proxy**: validates and forwards hypercalls from authorized guest processes to
  the VMM.

The rekernel explicitly does NOT provide: a VFS, networking, device drivers (beyond
the hypercall interface), signal delivery, or a user/group permission model. Estimated
size: low thousands of lines of Rust.

### IPDL Integration

Firefox's IPDL (IPC Protocol Definition Language) stack is modified at the transport layer
only:

```
.ipdl protocol definitions           (unchanged)
IPDL compiler / generated actors      (unchanged)
IPC::MessageChannel                   (unchanged)
NodeChannel / IPC::Channel            ← replaced with HypercallChannel
ipc::SharedMemory                     ← replaced with shm_create/shm_map
ParamTraits<FileDescriptor>           ← replaced with handle table
```

All existing IPDL protocol definitions, generated actor code, and Firefox code that calls
into IPDL actors remain unchanged. The modification is confined to the transport backend.

## Phases

### Phase 1: Hypervisor with Hypercall API

**Goal**: A minimal hypervisor (using KVM) that can launch a guest, handle VM exits, and
service the hypercall API.

**Deliverables**:
- KVM-based VMM that sets up guest memory, vCPUs, and boots a guest binary.
- Implementation of all ~10 hypercalls (channel_send/recv/wait/create,
  shm_create/map/unmap, signal_create/notify/wait).
- Host-side handle table mapping guest handles to host-side resources.
- Shared memory implemented via mapping host pages into guest physical address space.
- Test harness: a bare-metal guest program that exercises all hypercalls and validates
  correctness (message delivery, shared memory coherence, handle passing).

**Key design decisions**:
- VMM language: Rust (consistency with guest kernel, safety).
- KVM interface via `kvm-ioctls` crate or direct ioctl wrappers.
- Single vCPU initially; multi-vCPU in Phase 2.
- Hypercall ABI: register-based (rax = hypercall number, rdi/rsi/rdx/r10/r8/r9 = args),
  matching Linux syscall convention for familiarity.

### Phase 2: Guest Rekernel

**Goal**: A Rust rekernel that boots inside the Phase 1 hypervisor, runs user-mode
processes, and provides a syscall interface for memory management, threading, and IPC.

**Deliverables**:
- Boot sequence: set up GDT, IDT, page tables, transition to long mode (if not already).
- Process abstraction: separate CR3 per process, ELF loader for guest binaries.
- Syscall interface (via `syscall`/`sysret`):
  - Memory: mmap, munmap, mprotect.
  - Threading: clone (threads), futex, exit.
  - IPC (in-guest): shared memory mapping between guest processes, futex-based signaling.
  - Hypercall forwarding: validated proxy to VMM hypercalls for authorized processes.
- Scheduler: basic round-robin across guest threads/processes, multi-vCPU support.
- Test harness: two guest user-mode processes communicating via in-guest shared memory
  and via host hypercalls, demonstrating both isolation and communication.

**Key design decisions**:
- Rekernel only — no VFS, no networking, no device drivers.
- `unsafe` Rust confined to: pagetable manipulation, context switch, `vmcall` instruction,
  MSR setup for syscall/sysret.
- Use `x86_64` crate for pagetable structures and control register abstractions.

### Phase 2.5: dwplay Demo

**Goal**: Run dwplay — a minimal browser-like application — inside the Revisor VM to
validate the full architecture end-to-end before tackling Firefox.

dwplay is a dwitter player that uses QuickJS (JavaScript engine) and PlutoVG (Canvas2D
renderer) to execute and display creative JavaScript animations. It has the same
component structure as a browser: JS engine → renderer → display compositor.

```
HOST                              GUEST VM
                             ┌──────────────────────────┐
SDL2 display  ◄── shm ───►  │  Rekernel (ring 0)       │
              ◄── signal ──► │   ┌──────────────────┐   │
                             │   │ QuickJS + PlutoVG │   │
                             │   │ (ring 3)          │   │
                             │   └──────────────────┘   │
                             └──────────────────────────┘
```

**Deliverables**:
- Port QuickJS and PlutoVG to run as a single guest user-mode process on the rekernel
  (requires libc stubs for malloc, memcpy, math functions, etc.).
- Shared memory framebuffer: the guest renders frames into a shared memory region
  mapped by `shm_map`. The host reads pixels directly — no copying through channels.
- Frame signaling: the guest calls `signal_notify` after each frame. The host waits for
  the signal and updates the SDL2 display.
- Channel-based control: the host sends dweet source code and configuration to the guest
  via `channel_send`/`channel_recv`, mirroring the IPDL request/response pattern.
- Animation loop: the guest runs the dweet `u(t)` function each frame, renders to the
  PlutoVG surface, copies pixels to the shared memory framebuffer, and signals the host.
- Demonstrate multiple dweets from the `dweets/` directory rendering correctly.

**What this validates**:
- Shared memory framebuffer pattern (compositor surface, zero-copy).
- Channel-based message passing (IPDL transport pattern).
- Signal-based async notification (frame ready).
- Running real C code (QuickJS, PlutoVG) on the rekernel with minimal libc.
- End-to-end latency: is the hypercall overhead acceptable for 60fps rendering?

### Phase 3: Firefox IPDL Port

**Goal**: Port Firefox's IPDL transport layer to use the hypercall API, and run the
Firefox renderer as a guest process inside the Revisor VM.

**Deliverables**:
- `HypercallChannel`: replacement for `NodeChannel` in `ipc/glue/` that uses
  `channel_send`/`channel_recv`/`channel_wait` guest syscalls (which the rekernel
  proxies to VMM hypercalls).
- `HypercallSharedMemory`: replacement for `ipc::SharedMemory` using `shm_create`/`shm_map`.
- Handle translation: `ParamTraits<FileDescriptor>` serializes/deserializes handle IDs
  instead of file descriptors.
- Host-side VMM integration: translate hypercalls into real IPDL operations to communicate
  with the unmodified browser chrome, compositor, and networking processes.
- Build system integration: cross-compile the renderer for the guest environment (no libc
  networking, no filesystem — replaced by hypercall-backed stubs or removed).
- Demonstrate a Firefox renderer process running inside the VM, loading and rendering a
  web page, with composited output displayed by the host compositor.

**Key challenges**:
- The renderer links against a large portion of Firefox. Identify and stub out or replace
  OS dependencies (file I/O, networking, etc.) that are not available in the guest.
- Synchronous IPDL messages incur 3+ VM exits per round-trip. Audit renderer-to-chrome
  protocols and convert sync messages to async where possible.
- Framebuffer/compositing: use shared memory (shm_create) for the rendered surface to
  avoid copying pixel data through the message channel.

### Phase 4: Sub-Process JS Engine Isolation

**Goal**: Split the JavaScript engine (SpiderMonkey) into a separate guest process,
isolated from the renderer by guest pagetable separation, with in-guest IPC for
communication.

**Deliverables**:
- Factor SpiderMonkey execution into a separate guest process with its own address space.
- Define an in-guest IPC interface between renderer and JS engine for:
  - Script evaluation requests and results.
  - DOM binding calls (JS accessing/modifying DOM state in the renderer).
  - Callback/event dispatch from renderer to JS.
- Shared memory regions for high-frequency data (e.g., typed arrays, canvas backing
  buffers) mapped into both guest processes.
- Security policy: the JS engine process cannot make host-facing hypercalls — all
  external communication is mediated by the renderer.
- Performance evaluation: measure overhead of the isolation boundary on JS-heavy
  benchmarks (Speedometer, JetStream, MotionMark) compared to unmodified Firefox.
- Security evaluation: demonstrate that a simulated JS engine compromise (arbitrary
  read/write within the JS process) cannot access renderer memory.

**Key challenges**:
- DOM bindings are the hot path. SpiderMonkey accesses DOM objects frequently and
  synchronously. The in-guest IPC boundary must be low-latency — shared memory with
  futex signaling, not message-passing for every property access.
- Possible approach: a shared-memory region containing a "DOM proxy" data structure that
  the JS engine reads directly, with invalidation signaled by the renderer. Only mutating
  operations require a synchronous IPC round-trip.
- GC integration: SpiderMonkey's garbage collector needs to trace pointers into DOM
  objects. With the renderer in a separate address space, GC roots that reference
  renderer-side objects become opaque handles requiring cooperation from the renderer
  for marking/sweeping.

## Evaluation Plan

A top-conference systems paper requires rigorous evaluation along these axes:

### Security
- **Isolation validation**: demonstrate that a controlled memory corruption in the JS
  engine process cannot read renderer memory, and that a renderer compromise cannot
  escape the VM.
- **Attack surface comparison**: quantify the TCB (trusted computing base) — lines of
  code in the rekernel vs. lines of code in the renderer process that an attacker
  must further exploit to cross the isolation boundary.
- **CVE analysis**: take real SpiderMonkey CVEs and show that under Revisor, the exploit
  would be contained to the JS engine process.

### Performance
- **Macro benchmarks**: page load time, Speedometer, JetStream, MotionMark — compare
  Revisor-Firefox vs. stock Firefox.
- **Micro benchmarks**: hypercall round-trip latency, in-guest IPC latency, shared memory
  throughput, context switch cost within the guest.
- **Breakdown**: attribute overhead to VM exit/entry, hypercall handling, guest kernel
  syscalls, and in-guest IPC separately.

### Comparison
- Compare against existing isolation mechanisms:
  - Stock Firefox (single-process renderer, seccomp sandbox).
  - Chromium site isolation (separate OS processes per site).
  - RLBox (sandboxing via WebAssembly or process isolation for specific libraries).
  - gVisor / Firecracker (general-purpose VM-based sandboxing).
