#pragma once

#include <stdlib.h>

#include "x86-64.h"

#define MEMSIZE_PHYSICAL 0x200000

// Return the number of elements in an array
#define arraysize(array)  (sizeof(array) / sizeof(array[0]))

void sbrk_init();

// Process state type
enum procstate {
    P_FREE = 0,                         // free slot
    P_RUNNABLE,                         // runnable process
    P_BLOCKED,                          // blocked process
    P_BROKEN                            // faulted process
};

// Process descriptor type
struct proc {
    int p_pid;                        // process ID
    x86_64_registers p_registers;       // process's current registers
    enum procstate p_state;                // process state (see above)
    x86_64_pagetable* p_pagetable;      // process's page table
};

// virtual_memory_lookup(pagetable, va)
//    Returns information about the mapping of the virtual address `va` in
//    `pagetable`. The information is returned as a `vamapping` object,
//    which has the following components:
typedef struct vamapping {
    int pn;           // physical page number; -1 if unmapped
    uintptr_t pa;     // physical address; (uintptr_t) -1 if unmapped
    int perm;         // permissions; 0 if unmapped
} vamapping;

int virtual_memory_map(x86_64_pagetable* pagetable, uintptr_t va,
                       uintptr_t pa, size_t sz, int perm,
                       x86_64_pagetable* (*allocator)(void));

vamapping virtual_memory_lookup(x86_64_pagetable* pagetable, uintptr_t va);

void set_pagetable(x86_64_pagetable* pagetable);
