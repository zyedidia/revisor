#include <string.h>
#include <stdlib.h>

#include "kernel.h"
#include "x86-64.h"

// segments_init
//    Set up segment registers and interrupt descriptor table.
//
//    The segment registers distinguish the kernel from applications:
//    the kernel runs with segments SEGSEL_KERN_CODE and SEGSEL_KERN_DATA,
//    and applications with SEGSEL_APP_CODE and SEGSEL_APP_DATA.
//    The kernel segment runs with full privilege (level 0), but application
//    segments run with less privilege (level 3).
//
//    The interrupt descriptor table tells the processor where to jump
//    when an interrupt or exception happens. See k-interrupt.S.
//
//    The taskstate_t, segmentdescriptor_t, and pseduodescriptor_t types
//    are defined by the x86 hardware.

// Segment selectors
#define SEGSEL_KERN_CODE        0x8             // kernel code segment
#define SEGSEL_APP_CODE         0x10            // application code segment
#define SEGSEL_KERN_DATA        0x18            // kernel data segment
#define SEGSEL_APP_DATA         0x20            // application data segment
#define SEGSEL_TASKSTATE        0x28            // task state segment

// Segments
static uint64_t segments[7];

static void set_app_segment(uint64_t* segment, uint64_t type, int dpl) {
    *segment = type
        | X86SEG_S                    // code/data segment
        | ((uint64_t) dpl << 45)
        | X86SEG_P;                   // segment present
}

static void set_sys_segment(uint64_t* segment, uint64_t type, int dpl,
                            uintptr_t addr, size_t size) {
    segment[0] = ((addr & 0x0000000000FFFFFFUL) << 16)
        | ((addr & 0x00000000FF000000UL) << 32)
        | ((size - 1) & 0x0FFFFUL)
        | (((size - 1) & 0xF0000UL) << 48)
        | type
        | ((uint64_t) dpl << 45)
        | X86SEG_P;                   // segment present
    segment[1] = addr >> 32;
}

// Interrupt descriptors
static x86_64_gatedescriptor interrupt_descriptors[256];

// Processor state for taking an interrupt
static x86_64_taskstate kernel_task_descriptor;

static void set_gate(x86_64_gatedescriptor* gate, uint64_t type, int dpl,
                     uintptr_t function) {
    gate->gd_low = (function & 0x000000000000FFFFUL)
        | (SEGSEL_KERN_CODE << 16)
        | type
        | ((uint64_t) dpl << 45)
        | X86SEG_P
        | ((function & 0x00000000FFFF0000UL) << 32);
    gate->gd_high = function >> 32;
}

extern uint8_t exception_stack_end;

// Particular interrupt handler routines
extern void syscall_entry(void);
extern void default_int_handler(void);
extern void gpf_int_handler(void);
extern void pagefault_int_handler(void);
extern void timer_int_handler(void);

void segments_init(void) {
    // Segments for kernel & user code & data
    // The privilege level, which can be 0 or 3, differentiates between
    // kernel and user code.
    segments[0] = 0;
    set_app_segment(&segments[SEGSEL_KERN_CODE >> 3], X86SEG_X | X86SEG_L, 0);
    set_app_segment(&segments[SEGSEL_APP_CODE >> 3], X86SEG_X | X86SEG_L, 3);
    set_app_segment(&segments[SEGSEL_KERN_DATA >> 3], X86SEG_W, 0);
    set_app_segment(&segments[SEGSEL_APP_DATA >> 3], X86SEG_W, 3);
    set_sys_segment(&segments[SEGSEL_TASKSTATE >> 3], X86SEG_TSS, 0,
                    (uintptr_t) &kernel_task_descriptor,
                    sizeof(kernel_task_descriptor));

    x86_64_pseudodescriptor gdt;
    gdt.pseudod_limit = sizeof(segments) - 1;
    gdt.pseudod_base = (uint64_t) segments;

    // Kernel task descriptor lets us receive interrupts
    memset(&kernel_task_descriptor, 0, sizeof(kernel_task_descriptor));
    kernel_task_descriptor.ts_rsp[0] = (uintptr_t) &exception_stack_end;

    // Interrupt handler; most interrupts are effectively ignored
    memset(interrupt_descriptors, 0, sizeof(interrupt_descriptors));
    for (unsigned i = 16; i < arraysize(interrupt_descriptors); ++i) {
        set_gate(&interrupt_descriptors[i], X86GATE_INTERRUPT, 3,
                 (uint64_t) default_int_handler);
    }

    // Timer interrupt
    /* set_gate(&interrupt_descriptors[INT_TIMER], X86GATE_INTERRUPT, 0, */
    /*          (uint64_t) timer_int_handler); */

    // GPF and page fault
    set_gate(&interrupt_descriptors[INT_GPF], X86GATE_INTERRUPT, 0,
             (uint64_t) gpf_int_handler);
    set_gate(&interrupt_descriptors[INT_PAGEFAULT], X86GATE_INTERRUPT, 0,
             (uint64_t) pagefault_int_handler);

    x86_64_pseudodescriptor idt;
    idt.pseudod_limit = sizeof(interrupt_descriptors) - 1;
    idt.pseudod_base = (uint64_t) interrupt_descriptors;

    // Reload segment pointers
    asm volatile("lgdt %0\n\t"
                 "ltr %1\n\t"
                 "lidt %2"
                 : : "m" (gdt),
                     "r" ((uint16_t) SEGSEL_TASKSTATE),
                     "m" (idt)
                 : "memory");

    asm volatile("movw %%ax, %%fs; movw %%ax, %%gs"
                 : : "a" ((uint16_t) SEGSEL_KERN_DATA));

    // Set up control registers: check alignment
    uint32_t cr0 = rcr0();
    cr0 |= CR0_PE | CR0_PG | CR0_WP | CR0_AM | CR0_MP | CR0_NE;
    lcr0(cr0);

    // set up syscall/sysret
    wrmsr(MSR_IA32_KERNEL_GS_BASE, 0);
    wrmsr(MSR_IA32_STAR, ((uintptr_t) SEGSEL_KERN_CODE << 32)
          | ((uintptr_t) SEGSEL_APP_CODE << 48));
    wrmsr(MSR_IA32_LSTAR, (uint64_t) syscall_entry);
    wrmsr(MSR_IA32_FMASK, EFLAGS_TF | EFLAGS_DF | EFLAGS_IF
          | EFLAGS_IOPL_MASK | EFLAGS_AC | EFLAGS_NT);
}

void kinit(void) {
    segments_init();

    sbrk_init();
    void* tls = malloc(4096);
    wrmsr(MSR_IA32_GS_BASE, (uint64_t) tls);
}

void proc_init(struct proc* p) {
    memset(&p->p_registers, 0, sizeof(p->p_registers));

    p->p_registers.reg_cs = SEGSEL_APP_CODE | 3;
    p->p_registers.reg_fs = SEGSEL_APP_DATA | 3;
    p->p_registers.reg_gs = SEGSEL_APP_DATA | 3;
    p->p_registers.reg_ss = SEGSEL_APP_DATA | 3;
    p->p_registers.reg_rflags = EFLAGS_IF;
}

void set_pagetable(x86_64_pagetable* pagetable) {
    assert(PAGEOFFSET(pagetable) == 0); // must be page aligned
    lcr3(ka2pa((uintptr_t) pagetable));
}
