ENTRY(_start)

KTEXT_VMA  = 0xffffffff80000000;
KERNEL_VMA = 0xffff800000000000;
HIGH_START = KTEXT_VMA + 0x40000000 + 0x100000; /* 0xffff_ffff_8000_0000 + 0x4000_0000 + 0x10_0000 */

SECTIONS {
    . = 0x40000000;

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
