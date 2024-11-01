ENTRY(_start);

PHDRS {
    text PT_LOAD;
    data PT_LOAD;
}

SECTIONS {
    . = 0x1000;
    .interrupt_handler : {
        KEEP(*(.interrupt_handler))
    }

    . = 0x020000;

    .text : {
        __text = .;
        *(.text)
        *(.text.*)
        __text_end = .;
    } :text

    . = 0x40000;

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    } :data

    .data : {
        *(.data)
        *(.data.*)
    } :data

    .eh_frame : {
        KEEP(*(.eh_frame))
        *(.eh_frame.*)
    } :data

    .bss : {
        __bss = .;
        *(.bss)
        *(.bss.*)
        __bss_end = .;
    } :data

    /DISCARD/ : {
        *(.comment)
        *(.note.*)
    }
}
