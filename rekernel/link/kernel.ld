ENTRY(_start)

#if defined AMD64
KTEXT_VMA  = 0xffffffff80000000;
KERNEL_VMA = 0xffff800000000000;
#elif defined ARM64
KTEXT_VMA  = 0xffffffc000000000;
KERNEL_VMA = KTEXT_VMA;
#endif
LOW_START  = 0x40000000;
HIGH_START = KTEXT_VMA + LOW_START + 0x100000;

SECTIONS {
    . = LOW_START;

    .lowtext : {
        KEEP(*(.lowtext*))
        . = ALIGN(8);
    }
    .lowdata : {
        *(.lowdata*)
        . = ALIGN(8);
    }

    . = HIGH_START;

    .text : {
        _code = .;
        *(.text*)
        *(.gnu.linkonce.t*)
        KEEP(*(.fini*))

        . = ALIGN(8);

        PROVIDE_HIDDEN ( __preinit_array_start = . );
        KEEP (*(.preinit_array))
        PROVIDE_HIDDEN ( __preinit_array_end = . );

        PROVIDE_HIDDEN ( __init_array_start = . );
        KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))
        KEEP (*(.init_array .ctors))
        PROVIDE_HIDDEN ( __init_array_end = . );

        PROVIDE_HIDDEN ( __fini_array_start = . );
        KEEP (*(SORT_BY_INIT_PRIORITY(.fini_array.*) SORT_BY_INIT_PRIORITY(.dtors.*)))
        KEEP (*(.fini_array .dtors))
        PROVIDE_HIDDEN ( __fini_array_end = . );
    }

    .rodata : {
        _rodata = .;
        *(.rodata*)
        *(.gnu.linkonce.r*)
        *(.srodata*)

        . = ALIGN(8);
    }

    .data : {
        _data = .;
        *(.data*)
        *(.gnu.linkonce.d*)
        *(.sdata*)
        *(.gnu.linkonce.s*)
        . = ALIGN(8);
    }

    _edata = .;

    .bss : {
        _bss = .;
        *(.bss*)
        *(.gnu.linkonce.b*)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(8);
    }

    .stack : {
        . = ALIGN(0x1000);
        *(.stack*)
        . = ALIGN(0x1000);
    }

    _end = .;

    _heap_start = (. - KTEXT_VMA + KERNEL_VMA);

    /DISCARD/ : {
        *(.comment)
        *(note.*)
    }
}
