module proc;

import arch.regs;
import arch.vm;
import arch.trap;
import arch.sys;

import core.alloc;
import core.lib;
import core.math;
import core.interval;
import core.vector;

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
    uintptr MMAP_START = 0x0070_0000_0000,
    usize MMAP_SIZE    = gb(512),
    usize BRK_BASE     = gb(4),
    int ARGC_MAX       = 1024,
}

struct Proc {
    enum State {
        RUNNABLE,
        BLOCKED,
        EXITED,
    }

    Trapframe trapframe;
    Context context;

    Pagetable* pt;

    int pid;
    uintptr brk;

    IntervalTree!(VmArea) vmas;
    IntervalTree!(Empty) free_vmas;

    FdTable fdtable;

    Proc* parent;
    Vector!(Proc*) children;
    void* wq;

    Proc* next;
    Proc* prev;
    State state;

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
        kernel_map(pt);

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

    static Proc* make_from_parent(Proc* parent) {
        return null;
    }

    static Proc* make_from_file(immutable(char)* pathname, int argc, immutable(char)** argv) {
        void* f = fopen(pathname, "rb");
        if (!f) {
            return null;
        }
        ubyte[] buf = readfile(f);
        if (!buf)
            return null;
        ensure(fclose(f) == 0);

        Proc* p = Proc.make_empty();
        if (!p)
            goto err;
        if (!p.setup(buf.ptr, argc, argv))
            goto err;

        kfree(buf);

        p.state = State.RUNNABLE;

        return p;
err:
        kfree(buf);
        kfree(p);
        return null;
    }

    bool load(ubyte* buf, ref uintptr base, ref uintptr last, ref uintptr entry) {
        FileHeader* ehdr = cast(FileHeader*) buf;

        // TODO: check header
        uintptr dyn_base = 0;
        if (ehdr.type != ET_DYN && ehdr.type != ET_EXEC) {
            return false;
        }

        // TODO: harden the loader against adversarial ELF files.

        ProgHeader[] phdr = (cast(ProgHeader*) (buf + ehdr.phoff))[0 .. ehdr.phnum];

        base = uintptr.max;
        foreach (ref ProgHeader iter; phdr) {
            if (iter.type != PT_LOAD)
                continue;
            // TODO: permissions
            uintptr start = trunc(iter.vaddr, iter.align_);
            uintptr end = ceil(iter.vaddr + iter.memsz, iter.align_);
            uintptr offset = iter.vaddr - start;

            void* segment;
            if (ehdr.type == ET_EXEC) {
                segment = aligned_alloc(PAGESIZE, end - start);
                if (!segment)
                    goto err;
                if (!pt.map_region(start, ka2pa(segment), end - start, Perm.READ | Perm.WRITE | Perm.EXEC | Perm.USER))
                    goto err;
            } else {
                ubyte[] ka;
                if (dyn_base == 0) {
                    uintptr addr;
                    if (!map_vma_any(end - start, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0, addr, ka))
                        goto err;
                    dyn_base = addr;
                } else {
                    if (!map_vma(dyn_base + start, end - start, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0, ka))
                        goto err;
                }
                segment = ka.ptr;
            }

            memcpy(segment + offset, buf + iter.offset, iter.filesz);
            memset(segment + offset + iter.filesz, 0, iter.memsz - iter.filesz);

            if (dyn_base + end > last)
                last = dyn_base + end;
            if (dyn_base + start < base)
                base = dyn_base + start;
        }

        entry = dyn_base + ehdr.entry;

        return true;
err:
        return false;
    }

    bool setup(ubyte* buf, int argc, immutable(char)** argv) {
        if (argc <= 0 || argc >= ARGC_MAX)
            return false;

        uintptr base, last, entry, interp_base, interp_last, interp_entry;
        if (!load(buf, base, last, entry))
            return false;
        ubyte[] ka;

        FileHeader* ehdr = cast(FileHeader*) buf;
        ProgHeader[] phdr = (cast(ProgHeader*) buf + ehdr.phoff)[0 .. ehdr.phnum];

        char* interp_name = elf_interp(buf);
        if (interp_name) {
            void* f = fopen(interp_name, "rb");
            if (!f)
                return false;
            ubyte[] interp = readfile(f);
            if (!buf)
                return false;
            ensure(fclose(f) == 0);
            if (!this.load(interp.ptr, interp_base, interp_last, interp_entry))
                return false;
            kfree(interp);
        }

        brk = BRK_BASE;

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

        trapframe.user_sp = p_uargv;

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
        *av++ = Auxv(AT_BASE, interp_base);
        *av++ = Auxv(AT_PHDR, base + ehdr.phoff);
        *av++ = Auxv(AT_PHNUM, ehdr.phnum);
        *av++ = Auxv(AT_PHENT, ProgHeader.sizeof);
        *av++ = Auxv(AT_ENTRY, entry);
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

        if (interp_entry)
            trapframe.epc = interp_entry;
        else
            trapframe.epc = entry;
        trapframe.setup();

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

    bool map_vma_any(usize length, int prot, int flags, int fd, ssize offset, ref uintptr addr, ref ubyte[] ka) {
        usize size = ceilpg(length);
        Interval!(Empty) i;
        // Find a region that is large enough.
        if (!free_vmas.find(size, i)) {
            return false;
        }

        addr = i.start;

        return map_vma(i.start, length, prot, flags, fd, offset, ka);
    }

    bool map_vma(uintptr start, usize length, int prot, int flags, int fd, ssize offset, ref ubyte[] ka) {
        usize size = ceilpg(length);

        if (start < MMAP_START || start + size >= MMAP_START + MMAP_SIZE) {
            return false;
        }

        Interval!(VmArea) v;
        while (vmas.overlaps(start, size, v)) {
            ensure(vmas.remove(v.start, v.size));
            if (v.start < start) {
                ensure(vmas.add(v.start, start - v.start, v.val));
            }
            if ((v.start + v.size) > (start + size)) {
                ensure(vmas.add(start + size, (v.start + v.size) - (start + size), v.val));
            }
        }

        return map_vma_no_overlap(start, length, prot, flags, fd, offset, ka);
    }

    bool map_vma_no_overlap(uintptr start, usize length, int prot, int flags, int fd, ssize offset, ref ubyte[] ka) {
        usize size = ceilpg(length);
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
        if (ok) {
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
        }

        ka = kzalloc(size);
        if (!ka)
            return false;
        ensure(pt.map_region(start, ka2pa(ka.ptr), ka.length, Perm.READ | Perm.WRITE | Perm.EXEC | Perm.USER));

        if (fd >= 0) {
            VFile file;
            if (!fdtable.get(fd, file))
                return false;
            if (!file.lseek || !file.read)
                return false;
            ssize orig = file.lseek(file.dev, &this, 0, SEEK_CUR);
            file.lseek(file.dev, &this, offset, SEEK_SET);
            ubyte[PAGESIZE] buf = void;
            ssize n, total;
            usize remaining = length;
            assert(length <= ka.length);
            while ((n = file.read(file.dev, &this, buf.ptr, min(buf.length, remaining))) != 0) {
                memcpy(&ka[total], buf.ptr, n);
                total += n;
                remaining -= n;
            }
            file.lseek(file.dev, &this, orig, SEEK_SET);
        }

        return true;
    }

    bool unmap_vma(uintptr start, usize size) {
        if (!vmas.remove(start, size)) {
            return false;
        }
        if (!free_vmas.add(start, size, Empty())) {
            return false;
        }
        // TODO: handle unmapping with lazy mapping (need to free pages individually)
        uint lvl;
        Pte* pte = pt.walk(start, lvl);
        if (pte && pte.valid)
            kfree(cast(void*) pa2ka(pte.pa()));
        for (usize i = 0; i < size; i += PAGESIZE) {
            pte = pt.walk(start + i, lvl);
            if (!pte || !pte.valid) {
                continue;
            }
            pte.valid = 0;
        }
        return true;
    }
}
