#pragma once

#include <stdint.h>

struct pte {
    uint64_t valid:1;
    uint64_t table:1;
    uint64_t index:3; // mair index
    uint64_t ns:1; // non-secure
    uint64_t ap:2; // access permission
    uint64_t sh:2; // shareable
    uint64_t af:1; // access fault
    uint64_t ng:1; // not global
    uint64_t addr:36;
    uint64_t _r2:2;
    uint64_t gp:1;  // guarded page
    uint64_t dbm:1; // dirty bit modifier
    uint64_t contiguous:1;
    uint64_t pxn:1; // privileged execute never
    uint64_t uxn:1; // unprivileged execute never
    uint64_t cow:1; // copy-on-write (software)
    uint64_t sw:3;  // reserved for software
    uint64_t _r3:5;
};

_Static_assert(sizeof(struct pte) == sizeof(uint64_t), "pte size");

struct __attribute__((aligned(4096))) pagetable {
    struct pte entries[512];
};
