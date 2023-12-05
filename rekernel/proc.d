module proc;

import arch.regs;
import arch.vm;
import arch.trap;
import arch.sys;

import core.alloc;
import core.lib;

import elf;
import vm;

private enum ALIGN = (PAGESIZE - 1);

private uintptr truncpg(uintptr addr) {
    return addr & ~ALIGN;
}

private uintptr ceilpg(uintptr addr) {
    return (addr + ALIGN) & ~ALIGN;
}

private enum {
    KSTACK_SIZE = 4 * PAGESIZE,
    USTACK_SIZE = 8 * PAGESIZE,
    USTACK_VA = 0x7fff0000,
}

struct Proc {
    Trapframe trapframe;
    Context context;

    Pagetable* pt;

    int pid;

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
        if (!p.setup())
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
            ubyte[] segment = kalloc(end - start);
            if (!segment)
                goto err;

            if (lseek(kfd, iter.offset, SEEK_SET) < 0)
                goto err;
            if (read(kfd, segment.ptr, iter.filesz) != iter.filesz)
                goto err;
            memset(segment.ptr + iter.filesz, 0, iter.memsz - iter.filesz);

            if (!pt.map_region(start, ka2pa(segment.ptr), segment.length, Perm.READ | Perm.WRITE | Perm.USER))
                goto err;
        }

        trapframe.epc = ehdr.entry;
        kfree(phdr);

        return true;
err:
        kfree(phdr);
        return false;
    }

    bool setup() {
        ubyte[] ustack = kzalloc(USTACK_SIZE);
        if (!ustack) {
            return false;
        }

        if (!pt.map_region(USTACK_VA, ka2pa(ustack.ptr), ustack.length, Perm.READ | Perm.WRITE | Perm.USER)) {
            kfree(ustack);
            return false;
        }

        trapframe.regs.sp = USTACK_VA + USTACK_SIZE;

        return true;
    }
}
