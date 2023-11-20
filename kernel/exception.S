.text

# Interrupt handlers
.align 2

.globl gpf_int_handler
gpf_int_handler:
	pushq $13               // trap number
	jmp generic_exception_handler

.globl pagefault_int_handler
pagefault_int_handler:
	pushq $14
	jmp generic_exception_handler

.globl timer_int_handler
timer_int_handler:
	pushq $0                // error code
	pushq $32
	jmp generic_exception_handler

.globl syscall_entry
syscall_entry:
	pushq $0
	pushq $48
	jmp generic_exception_handler

.globl default_int_handler
default_int_handler:
	pushq $0
	pushq $0x80
	jmp generic_exception_handler

generic_exception_handler:
	pushq %gs
	pushq %fs
	pushq %r15
	pushq %r14
	pushq %r13
	pushq %r12
	pushq %r11
	pushq %r10
	pushq %r9
	pushq %r8
	pushq %rdi
	pushq %rsi
	pushq %rbp
	pushq %rbx
	pushq %rdx
	pushq %rcx
	pushq %rax
	movq %rsp, %rdi
	call exception

.globl exception_return
exception_return:
	movq %rdi, %rsp
	popq %rax
	popq %rcx
	popq %rdx
	popq %rbx
	popq %rbp
	popq %rsi
	popq %rdi
	popq %r8
	popq %r9
	popq %r10
	popq %r11
	popq %r12
	popq %r13
	popq %r14
	popq %r15
	popq %fs
	addq $24, %rsp
	iretq

.globl exception_stack_end
exception_stack_start:
	.fill 0x8000,1,0
exception_stack_end:
