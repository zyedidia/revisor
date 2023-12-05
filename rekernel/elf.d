module elf;

enum {
    ELF_MAGIC = 0x464C457FU, // "\x7ELF" in little endian

    PT_LOAD = 1,
}

struct FileHeader {
    alias uword = ulong;

    uint magic;
    ubyte width;
    ubyte[11] _elf;
    ushort type;
    ushort machine;
    uint version_;
    uword entry;
    uword phoff;
    uword shoff;
    uint flags;
    ushort ehsize;
    ushort phentsize;
    ushort phnum;
    ushort shentsize;
    ushort shnum;
    ushort shstrndx;
}

struct ProgHeader {
    alias uword = ulong;

    uint type;
    uint flags;
    uword offset;
    uword vaddr;
    uword paddr;
    uword filesz;
    uword memsz;
    uword align_;
}
