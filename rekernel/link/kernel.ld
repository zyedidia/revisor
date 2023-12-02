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

	_end = .;

	/DISCARD/ : {
		*(.comment)
		*(note.*)
	}
}
