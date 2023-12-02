ENTRY(_start)

SECTIONS {
	. = 0x80000;

	.text : {
		_code = .;
		*(.text*)
		*(.gnu.linkonce.t*)
		. = ALIGN(0x1000);
	}

	.rodata : {
		_rodata = .;
		*(.rodata*)
		*(.gnu.linkonce.r*)

        . = ALIGN(8);
        __CTOR_LIST__ = .;
        *(.ctors)
        __CTOR_END__ = .;

        . = ALIGN(8);
        __DTOR_LIST__ = .;
        *(.dtors)
        __DTOR_END__ = .;

        . = ALIGN(8);
        __INIT_LIST__ = .;
        KEEP (*(.init_array))
        __INIT_END__ = .;

        . = ALIGN(8);
        __FINI_LIST__ = .;
        KEEP (*(.fini_array))
        __FINI_END__ = .;

		. = ALIGN(0x1000);
	}

	.data : {
		_data = .;
		*(.data*)
		*(.gnu.linkonce.d*)
		. = ALIGN(0x1000);
	}

	_edata = .;

	.bss : {
		_bss = .;
		*(.bss*)
		*(.gnu.linkonce.b*)
		*(COMMON)
		. = ALIGN(0x1000);
	}

    .stack : {
        *(.stack*)
        . = ALIGN(0x1000);
    }

	_end = .;

	/DISCARD/ : {
		*(.comment)
		*(note.*)
	}
}
