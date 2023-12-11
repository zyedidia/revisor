module file;

import core.lib;

import proc;
import syscall;

enum {
    AT_FDCWD = -100,
}

private immutable(char)* flags2cmode(int flags) {
    if ((flags & O_RDONLY) != 0) {
        return "r".ptr;
    }
    if ((flags & O_WRONLY) != 0) {
        return "w".ptr;
    }
    return "r+".ptr;
}

int file_new(VFile* vf, char* name, int flags, int mode) {
    int kfd = open(name, flags, mode);
    if (kfd < 0)
        return errno;
    void* cfile = fdopen(kfd, flags2cmode(flags));
    if (!cfile)
        return Err.BADF;
    vf.dev = cfile;
    vf.read = &file_read;
    vf.write = &file_write;
    vf.lseek = &file_lseek;
    vf.close = &file_close;
    return 0;
}

ssize file_read(void* dev, Proc* p, ubyte* buf, usize n) {
    return fread(buf, 1, n, dev);
}

ssize file_write(void* dev, Proc* p, ubyte* buf, usize n) {
    return fwrite(buf, 1, n, dev);
}

ssize file_lseek(void* dev, Proc* p, ssize off, uint whence) {
    return fseek(dev, off, whence);
}

int file_close(void* dev, Proc* p) {
    return fclose(dev);
}

struct VFile {
    void* dev;
    ssize function(void* dev, Proc* p, ubyte* buf, usize n) read;
    ssize function(void* dev, Proc* p, ubyte* buf, usize n) write;
    ssize function(void* dev, Proc* p, ssize off, uint whence) lseek;
    int function(void* dev, Proc* p) close;
}

private ssize rd_stdin(void* dev, Proc* p, ubyte* buf, usize n) {
    return fread(buf, 1, n, stdin);
}
private ssize wr_stdout(void* dev, Proc* p, ubyte* buf, usize n) {
    return fwrite(buf, 1, n, stdout);
}
private ssize wr_stderr(void* dev, Proc* p, ubyte* buf, usize n) {
    return fwrite(buf, 1, n, stderr);
}

struct FdTable {
    enum {
        NUM_FILE = 128,
    }

    VFile[NUM_FILE] files;
    bool[NUM_FILE] allocated;

    void alloc(int fd, VFile f) {
        assert(fd >= 0 && fd < NUM_FILE && !allocated[fd]);
        allocated[fd] = true;
        files[fd] = f;
    }

    VFile* alloc(ref int fd) {
        int i;
        for (i = 0; i < NUM_FILE; i++) {
            if (!allocated[i])
                break;
        }
        if (i >= NUM_FILE)
            return null;
        fd = i;
        allocated[fd] = true;
        return &files[fd];
    }

    void init() {
        alloc(0, VFile(
            null,      // dev
            &rd_stdin, // read
            null,      // write
            null,      // lseek
            null,      // close
        ));
        alloc(1, VFile(
            null,       // dev
            null,       // read
            &wr_stdout, // write
            null,       // lseek
            null,       // close
        ));
        alloc(2, VFile(
            null,       // dev
            null,       // read
            &wr_stderr, // write
            null,       // lseek
            null,       // close
        ));
    }

    bool get(int fd, ref VFile file) {
        if (has(fd)) {
            file = files[fd];
            return true;
        }
        return false;
    }

    bool remove(int fd) {
        if (has(fd)) {
            allocated[fd] = false;
            return true;
        }
        return false;
    }

    bool has(int fd) {
        return fd >= 0 && fd < NUM_FILE && allocated[fd];
    }
}
