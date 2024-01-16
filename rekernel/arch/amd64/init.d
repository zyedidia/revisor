module arch.amd64.init;

import arch.amd64.sys;
import arch.amd64.apic;

import core.lib;

__gshared TaskState task_descriptor;

private __gshared {
    ulong[7] segments;
    GateDescriptor[256] interrupt_descriptors;

    extern (C) {
        extern ubyte exception_stack_end;
        void syscall_entry();
        void default_int_handler();
        void gpf_int_handler();
        void pagefault_int_handler();
        void timer_int_handler();
    }
}

private void set_app_segment(ulong* segment, ulong type, int dpl) {
    *segment = type | X86SEG_S | (cast(ulong) dpl << 45) | X86SEG_P;
}

private void set_sys_segment(ulong* segment, ulong type, int dpl, uintptr addr, usize size) {
    segment[0] = ((addr & 0x0000000000FFFFFFUL) << 16)
        | ((addr & 0x00000000FF000000UL) << 32)
        | ((size - 1) & 0x0FFFFUL)
        | (((size - 1) & 0xF0000UL) << 48)
        | type
        | (cast(ulong) dpl << 45)
        | X86SEG_P;                   // segment present
    segment[1] = addr >> 32;
}

private void set_gate(GateDescriptor* gate, ulong type, int dpl, uintptr func) {
    gate.low = (func & 0x000000000000FFFFUL)
        | (SEGSEL_KERN_CODE << 16)
        | type
        | (cast(ulong) dpl << 45)
        | X86SEG_P
        | ((func & 0x00000000FFFF0000UL) << 32);
    gate.high = func >> 32;
}

private void segments_init() {
    segments[0] = 0;
    set_app_segment(&segments[SEGSEL_KERN_CODE >> 3], X86SEG_X | X86SEG_L, 0);
    set_app_segment(&segments[SEGSEL_APP_CODE >> 3], X86SEG_X | X86SEG_L, 3);
    set_app_segment(&segments[SEGSEL_KERN_DATA >> 3], X86SEG_W, 0);
    set_app_segment(&segments[SEGSEL_APP_DATA >> 3], X86SEG_W, 3);
    set_sys_segment(&segments[SEGSEL_TASKSTATE >> 3], X86SEG_TSS, 0, cast(uintptr) &task_descriptor, task_descriptor.sizeof);

    PseudoDescriptor gdt;
    gdt.limit = segments.sizeof - 1;
    gdt.base = cast(ulong) segments.ptr;

    // Kernel task descriptor lets us receive interrupts.
    memset(&task_descriptor, 0, task_descriptor.sizeof);
    task_descriptor.rsp[0] = cast(uintptr) &exception_stack_end;

    // Interrupt handler; most interrupts are effectively ignored.
    memset(interrupt_descriptors.ptr, 0, interrupt_descriptors.sizeof);
    for (uint i = 16; i < interrupt_descriptors.length; ++i) {
        set_gate(&interrupt_descriptors[i], X86GATE_INTERRUPT, 3, cast(ulong) &default_int_handler);
    }

    // GPF and page fault.
    set_gate(&interrupt_descriptors[INT_GPF], X86GATE_INTERRUPT, 0, cast(ulong) &gpf_int_handler);
    set_gate(&interrupt_descriptors[INT_PAGEFAULT], X86GATE_INTERRUPT, 0, cast(ulong) &pagefault_int_handler);

    PseudoDescriptor idt;
    idt.limit = interrupt_descriptors.sizeof - 1;
    idt.base = cast(ulong) interrupt_descriptors.ptr;

    // Reload segment pointers
    asm {
        "lgdt %0\n" ~
        "ltr %1\n" ~
        "lidt %2"
        : : "m" (gdt),
            "r" (cast(ushort) SEGSEL_TASKSTATE),
            "m" (idt)
        : "memory";
    }

    asm {
        "movw %%ax, %%fs; movw %%ax, %%gs"
            : : "a" (cast(ushort) SEGSEL_KERN_DATA);
    }

    // Set up control registers: check alignment
    uint cr0 = rd_cr0();
    cr0 |= CR0_PE | CR0_PG | CR0_WP | CR0_AM | CR0_MP | CR0_NE;
    wr_cr0(cr0);

    // set up syscall/sysret
    wr_msr(MSR_IA32_KERNEL_GS_BASE, 0);
    wr_msr(MSR_IA32_STAR, (cast(uintptr) SEGSEL_KERN_CODE << 32) | (cast(uintptr) SEGSEL_APP_CODE << 48));
    wr_msr(MSR_IA32_LSTAR, cast(ulong) &syscall_entry);
    wr_msr(MSR_IA32_FMASK, EFLAGS_TF | EFLAGS_DF | EFLAGS_IF | EFLAGS_IOPL_MASK | EFLAGS_AC | EFLAGS_NT);
}

private __gshared {
    LocalApic* lapic = cast(LocalApic*) pa2ka(0xFEE00000);
}

private void lapic_init() {
    enum HZ = 100;

    lapic.enable(INT_IRQ + IRQ_SPURIOUS);

    lapic.write(LAPIC_REG_TIMER_DIVIDE, LAPIC_TIMER_DIVIDE_1);
    lapic.write(LAPIC_REG_LVT_TIMER, LAPIC_TIMER_PERIODIC | (INT_IRQ + IRQ_TIMER));
    lapic.write(LAPIC_REG_TIMER_INITIAL_COUNT, 1_000_000_000 / HZ);

    lapic.write(LAPIC_REG_LVT_LINT0, LAPIC_LVT_MASKED);
    lapic.write(LAPIC_REG_LVT_LINT1, LAPIC_LVT_MASKED);

    lapic.write(LAPIC_REG_LVT_ERROR, INT_IRQ + IRQ_ERROR);

    lapic.error();
    lapic.ack();
}

private void interrupts_init() {
    lapic_init();

    // Disable old programmable interrupt controller.
    enum {
        IO_PIC1 = 0x20,
        IO_PIC2 = 0xA0,
    }

    outb!(IO_PIC1 + 1)(0xFF);
    outb!(IO_PIC2 + 1)(0xFF);
}

void arch_init() {
    segments_init();
    // interrupts_init();
}
