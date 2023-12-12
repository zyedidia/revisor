.globl _start
_start:
	movq $1, %rax
	movq $1, %rdi
	leaq hello, %rsi
	movq $6, %rdx
	syscall

	movq $60, %rax
	syscall

hello:
	.asciz "hello\n"
