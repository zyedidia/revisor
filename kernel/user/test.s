.globl _start
_start:
	mov $42, %rax
	nop
	nop
	nop
	int $0x80
