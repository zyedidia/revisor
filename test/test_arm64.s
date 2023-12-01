.globl _start
_start:
	mov x28, x0
	mov x8, #0
	mov x0, #1
	adr x1, s
	mov x2, #12
	str xzr, [x28]
	// exit
	mov x8, #1
	str xzr, [x28]

s:
	.asciz "hello world\n"
