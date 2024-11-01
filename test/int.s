
.section ".interrupt_handler", "ax"
.global handler
handler:
	// return address
	movq 0(%rsp), %r15
	mov %rsp, %rdi
	mov $39, %rax
	syscall
	jmpq *%r15

.text

.global _start
_start:
	mov $39, %rax
	//mov %cs, %rdi
	mov %rsp, %rdi
	syscall

	movl $5, %r13d
	movq %rsp, %r14
.L2:
	movq %r14, %rsp
	int $0x80
resume:
	subl $1, %r13d
	jne .L2
	mov $60, %rax
	syscall
