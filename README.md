# Revisor

Revisor is a hypervisor that exposes a Unix-like API to its guest kernel via
hypercalls. This enables a guest kernel to directly interact with the host OS
as if it were a normal user process. Unlike a normal process though, the guest
can still make use of virtualized privileged hardware features, such as virtual
memory, privilege levels, and timers.

Revisor makes it easy to build and explore new operating system designs. You
can make an OS that runs within Revisor, and shells out to the host for file
system and network access. As a result, you don't have to maintain a
complicated set of device drivers, file system code, or a network stack, and
can focus on the parts of the OS that are interesting to you. If you would
like, you can still implement custom file systems or networking via virtualized
devices or via the hypercall API. Your custom OS will be able to run on any
system that supports Revisor (i.e., any x86-64 or ARM64 machine running Linux
that has KVM). We also provide an example OS that aims to be compatible with a
subset of the Linux API, implemented in around 3,000 lines of code.

These minimal custom "rekernels" (kernels that run within Revisor) can be used
for a number of applications:

1. User-level sandboxing: a rekernel can implement a container that restricts
   the resources from the host OS that are available to guest programs.
   Restrictions can be entirely implemented within the guest kernel, or can be
   implemented in both the hypervisor and the guest kernel, if the threat model
   a compromised guest kernel is a concern (i.e., the guest kernel is only
   trusted to isolate processes within the sandbox, and the hypervisor is
   trusted to contain the guest to a particular directory).
2. Program tracing: Linux's ptrace API is commonly used to trace another
   program, but it is very slow and complex. A rekernel can similarly control
   processes and make use of debug features (breakpoints/watchpoints), but is
   much faster, and allows the rekernel to safely share an address space with
   the tracee and handle/trace any system calls it makes via virtualized
   privilege levels.
3. Record-and-replay: Record-and-replay is an application of program tracing
   that can be implemented with Revisor. In particular, since a rekernel
   controls the exact scheduling of processes being recorded, it can use a
   deterministic algorithm and use a single core to ensure replayability even
   for multi-threaded programs.
4. Garbage collection: garbage collectors can be accelerated by making use of
   virtual memory and pagetable information (dirty pages) that is available to
   a rekernel but not to a normal process.

In general, custom rekernels can give you complete control over how an
application is run since you control what system calls are available to it, how
it is scheduled, and more. You are able to implement a custom OS that does
exactly what you need, while minimizing the effort needed to write such an OS
by taking advantage of the capabilities provided by the hypervisor and host OS.

In the future we may also add support for macOS or Windows, allowing for
rekernels to run portably across all major operating systems. The Go hypervisor
is written in a way such that it can portably provide its Unix-like hypercall
API.

This project is currently heavily in progress. Please stay tuned for more
information.
