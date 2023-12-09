.globl _start
_start:
	mov x8, 64
	mov x0, 1
	mrs x0, tpidr_el0
	adr x1, hello
	mov x2, 6
	svc #0
	mov x8, 93
	svc #0

hello:
	.asciz "hello\n"
