ENTRY(_start)

SECTIONS {
    . = 0x80000;

    .init : {
        KEEP (*(.text.init.enter))
        KEEP (*(.data.init.enter))
        KEEP (*(SORT_BY_NAME(.init) SORT_BY_NAME(.init.*)))
    }

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

    /DISCARD/ : {
        *(.comment)
        *(note.*)
    }
}
