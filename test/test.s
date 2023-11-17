.globl _start
_start:
	mov $42, %rax
	out %al, %dx
	hlt
