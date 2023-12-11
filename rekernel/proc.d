module proc;

import arch.regs;
import arch.vm;
import arch.trap;
import arch.sys;

import core.alloc;
import core.lib;
import core.math;
import core.interval;

import elf;
import vm;
import schedule;
import queue;
import sys;
import file;

private enum {
    usize KSTACK_SIZE  = 4 * PAGESIZE,
    usize USTACK_SIZE  = 16 * PAGESIZE,
    uintptr USTACK_VA  = 0x0000_7fff_0000,
    uintptr MMAP_START = 0x0001_0000_0000,
    usize MMAP_SIZE    = gb(512),
    int ARGC_MAX       = 1024,
}

struct Proc {
    enum State {
        RUNNABLE = 0,
        BLOCKED = 1,
        EXITED = 2,
    }

    Trapframe trapframe;
    Context context;

    Pagetable* pt;

    int pid;
    uintptr brk;

    IntervalTree!(VmArea) vmas;
    IntervalTree!(Empty) free_vmas;

    FdTable fdtable;

    Proc* next;
    Proc* prev;
    State state;
    void* wq;

    align(16) ubyte[KSTACK_SIZE] kstack;
    static assert(kstack.length % 16 == 0);

    // Disable opAssign because it would overflow the stack.
    @disable void opAssign(Proc);

    uintptr kstackp() {
        return cast(uintptr) kstack.ptr + kstack.length;
    }

    static void entry(Proc* p) {
        wrpt(p.pt);
        usertrapret(p);
    }

    static Proc* make_empty() {
        Pagetable* pt = knew!(Pagetable)();
        if (!pt)
            return null;
        // TODO: kernel_procmap

        Proc* p = knew!(Proc)();
        if (!p) {
            pt.free();
            kfree(pt);
            return null;
        }

        p.pid = 0;
        p.pt = pt;
        p.context = Context(cast(uintptr) &Proc.entry, p.kstackp());
        if (!p.free_vmas.add(MMAP_START, MMAP_SIZE, Empty())) {
            kfree(p);
            return null;
        }
        p.fdtable.init();

        return p;
    }

    static Proc* make_from_file(char* pathname, int argc, char** argv) {
        int kfd = open(pathname, O_RDONLY, 0);
        if (kfd < 0) {
            return null;
        }

        Proc* p = Proc.make_empty();
        if (!p)
            goto err;
        if (!p.load(kfd))
            goto err;
        if (!p.setup(argc, argv))
            goto err;

        close(kfd);

        return p;
err:
        close(kfd);
        kfree(p);
        return null;
    }

    bool load(int kfd) {
        FileHeader ehdr;
        if (read(kfd, &ehdr, FileHeader.sizeof) != FileHeader.sizeof) {
            return false;
        }

        // TODO: check header

        usize sz = ehdr.phnum * ProgHeader.sizeof;
        ProgHeader* phdr = cast(ProgHeader*) kalloc(sz);
        if (!phdr) {
            return false;
        }
        if (lseek(kfd, ehdr.phoff, SEEK_SET) < 0) {
            goto err;
        }
        if (read(kfd, phdr, sz) != sz) {
            goto err;
        }

        for (ProgHeader* iter = phdr; iter < &phdr[ehdr.phnum]; iter++) {
            if (iter.type != PT_LOAD)
                continue;
            uintptr start = truncpg(iter.vaddr);
            uintptr end = ceilpg(iter.vaddr + iter.memsz);
            uintptr offset = iter.vaddr - start;
            void* segment = aligned_alloc(PAGESIZE, end - start);
            if (!segment)
                goto err;

            if (lseek(kfd, iter.offset, SEEK_SET) < 0)
                goto err;
            if (read(kfd, segment + offset, iter.filesz) != iter.filesz)
                goto err;
            memset(segment + offset + iter.filesz, 0, iter.memsz - iter.filesz);

            if (!pt.map_region(start, ka2pa(segment), end - start, Perm.READ | Perm.WRITE | Perm.EXEC | Perm.USER))
                goto err;

            if (end > brk)
                brk = end;
        }

        trapframe.epc = ehdr.entry;
        kfree(phdr);

        return true;
err:
        kfree(phdr);
        return false;
    }

    bool setup(int argc, char** argv) {
        if (argc <= 0 || argc >= ARGC_MAX) {
            return false;
        }

        ubyte[] ustack = kzalloc(USTACK_SIZE);
        if (!ustack) {
            return false;
        }

        if (!pt.map_region(USTACK_VA, ka2pa(ustack.ptr), ustack.length, Perm.READ | Perm.WRITE | Perm.USER)) {
            kfree(ustack);
            return false;
        }

        uintptr[ARGC_MAX] argv_ptrs;

        ubyte* stack_top = ustack.ptr + ustack.length;
        uintptr ustack_top = USTACK_VA + ustack.length;
        char* p_argv = cast(char*) stack_top - PAGESIZE;
        uintptr p_uargv = ustack_top - PAGESIZE;

        for (int i = 0; i < argc; i++) {
            assert(argv[i]);
            usize len = strnlen(argv[i], 64);
            argv_ptrs[i] = p_uargv;
            memcpy(p_argv, argv[i], len);
            p_argv += len;
            *p_argv++ = 0;
            p_uargv += len + 1;
        }

        p_argv = cast(char*) stack_top - 2 * PAGESIZE;
        p_uargv = ustack_top - 2 * PAGESIZE;

        trapframe.regs.sp = p_uargv;

        long* p_argc = cast(long*) p_argv;
        *p_argc++ = argc;

        uintptr* p_argvp = cast(uintptr*) p_argc;
        uintptr* p_argvp_start = p_argvp;
        for (usize i = 0; i < argc; i++) {
            *p_argvp++ = argv_ptrs[i];
        }
        *p_argvp++ = 0;
        *p_argvp++ = 0; // envp

        Auxv* av = cast(Auxv*) p_argvp;
        *av++ = Auxv(AT_SECURE, 0);
        *av++ = Auxv(AT_ENTRY, trapframe.epc);
        *av++ = Auxv(AT_EXECFN, cast(ulong) p_argvp_start[0]);
        *av++ = Auxv(AT_PAGESZ, PAGESIZE);
        // TODO: use actual random bytes
        *av++ = Auxv(AT_RANDOM, p_argvp_start[0]);
        *av++ = Auxv(AT_HWCAP, 0x0);
        *av++ = Auxv(AT_HWCAP2, 0x0);
        *av++ = Auxv(AT_FLAGS, 0x0);
        *av++ = Auxv(AT_UID, 1000);
        *av++ = Auxv(AT_EUID, 1000);
        *av++ = Auxv(AT_GID, 1000);
        *av++ = Auxv(AT_EGID, 1000);
        *av++ = Auxv(AT_NULL, 0);

        state = State.RUNNABLE;

        return true;
    }

    void yield() {
        kswitch(null, &context, &scheduler);
    }

    void block(Queue* q, State s) {
        state = s;
        wq = q;
        q.push_front(&this);
        yield();
    }

    bool map_vma_any(usize size, int prot, int flags, ref uintptr addr) {
        Interval!(Empty) i;
        // Find a region that is large enough.
        if (!free_vmas.find(size, i)) {
            return false;
        }

        addr = i.start;

        return map_vma(i.start, size, prot, flags);
    }

    bool map_vma(uintptr start, usize size, int prot, int flags) {
        if (start < MMAP_START || start + size >= MMAP_START + MMAP_SIZE)
            return false;

        // Cannot overlap any existing intervals.
        Interval!(VmArea) v;
        if (vmas.overlaps(start, size, v)) {
            return false;
        }

        // Otherwise good to add.
        if (!vmas.add(start, size, VmArea(prot, flags))) {
            return false;
        }

        Interval!(Empty) i;
        free_vmas.overlaps(start, size, i);

        // Split the free region.
        bool ok = free_vmas.remove(i.start, i.size);
        assert(ok);
        // This needs to be atomic with the remove.
        if (start - i.start != 0) {
            ok = free_vmas.add(i.start, start - i.start, Empty());
            assert(ok);
        }
        if (i.size - size != 0) {
            if (!free_vmas.add(start + size, i.size - (start - i.start) - size, Empty())) {
                // If this fails, we might have problems.
                return false;
            }
        }

        ubyte[] mem = kalloc(size);
        assert(mem);
        ensure(pt.map_region(start, ka2pa(mem.ptr), mem.length, Perm.READ | Perm.WRITE | Perm.USER));

        return true;
    }

    bool unmap_vma(uintptr start, usize size) {
        if (!vmas.remove(start, size)) {
            return false;
        }
        if (!free_vmas.add(start, size, Empty())) {
            return false;
        }
        // TODO: actually unmap and free the pages
        return true;
    }
}
