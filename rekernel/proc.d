module proc;

import arch.regs;
import arch.vm;
import arch.trap;
import arch.sys;

import core.alloc;
import core.lib;
import core.math;

import elf;
import vm;

private enum {
    KSTACK_SIZE = 4 * PAGESIZE,
    USTACK_SIZE = 8 * PAGESIZE,
    ulong USTACK_VA = 0x7fff0000,
}

struct Proc {
    Trapframe trapframe;
    Context context;

    Pagetable* pt;

    int pid;
    uintptr brk;

    align(16) ubyte[KSTACK_SIZE] kstack;
    static assert(kstack.length % 16 == 0);

    // Disable opAssign because it would overflow the stack.
    @disable void opAssign(Proc);

    uintptr kstackp() {
        return cast(uintptr) kstack.ptr + kstack.length;
    }

    static void entry(Proc* p) {
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

        return p;
    }

    static Proc* make_from_file(const char* pathname) {
        int kfd = open(pathname, O_RDONLY, 0);
        if (kfd < 0) {
            return null;
        }

        Proc* p = Proc.make_empty();
        if (!p)
            goto err;
        if (!p.load(kfd))
            goto err;
        if (!p.setup(pathname))
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
            void* segment = aligned_alloc(PAGESIZE, end - start);
            if (!segment)
                goto err;

            if (lseek(kfd, iter.offset, SEEK_SET) < 0)
                goto err;
            if (read(kfd, segment + (iter.vaddr - start), iter.filesz) != iter.filesz)
                goto err;
            memset(segment + iter.filesz, 0, iter.memsz - iter.filesz);

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

    bool setup(const char* name) {
        ubyte[] ustack = kzalloc(USTACK_SIZE);
        if (!ustack) {
            return false;
        }

        if (!pt.map_region(USTACK_VA, ka2pa(ustack.ptr), ustack.length, Perm.READ | Perm.WRITE | Perm.USER)) {
            kfree(ustack);
            return false;
        }

        ubyte* stack_top = ustack.ptr + ustack.length;
        uintptr ustack_top = USTACK_VA + ustack.length;

        char* p_name = cast(char*) stack_top - PAGESIZE;
        uintptr p_uname = ustack_top - PAGESIZE;
        usize len = strnlen(name, 64) + 1;
        memcpy(p_name, name, len);

        ulong* p_argc = cast(ulong*) (stack_top - 2 * PAGESIZE);
        trapframe.regs.sp = ustack_top - 2 * PAGESIZE;
        *p_argc++ = 1;

        uintptr* p_argv = cast(uintptr*) p_argc;
        *p_argv++ = p_uname; // argv
        *p_argv++ = 0;
        *p_argv++ = 0; // envp

        Auxv* av = cast(Auxv*) p_argv;
        *av++ = Auxv(AT_ENTRY, trapframe.epc);
        *av++ = Auxv(AT_EXECFN, cast(ulong) p_argv[0]);
        *av++ = Auxv(AT_PAGESZ, PAGESIZE);
        *av++ = Auxv(AT_NULL, 0);

        return true;
    }
}
