OUTPUT_FORMAT(elf64-x86-64)
ENTRY(kernel_entry)

SECTIONS {
    .text 0x1000 : {
        _code_start = .;
        KEEP(*(.text.boot))
        *(.text*)
        . = ALIGN(8);
        _code_end = .;
    }
    .rodata : {
        . = ALIGN(8);
        _rodata_start = .;
        *(.srodata*)
        *(.rodata*)
        . = ALIGN(8);
        _rodata_end = .;
    }
    .data : { 
        . = ALIGN(8);
        _data_start = .;
        *(.sdata*)
        *(.data*)
        . = ALIGN(8);
        _data_end = .;
    } 
    .bss : {
        . = ALIGN(8);
        _bss_start = .;
        *(.sbss*)
        *(.bss*)
        *(COMMON)
        . = ALIGN(8);
        _bss_end = .;
    }

    .stack : {
        . = ALIGN(16);
        . += 16K;
        _stack_high = .;
    }

    .heap : {
        . = ALIGN(4K);
        _heap_start = .;
    }
}
