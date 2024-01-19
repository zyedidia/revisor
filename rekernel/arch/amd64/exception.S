#define SEGSEL_KERN_CODE 0x8
#define SEGSEL_APP_CODE  0x10
#define SEGSEL_KERN_DATA 0x18
#define SEGSEL_APP_DATA  0x20
#define SEGSEL_TASKSTATE 0x28

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
	pushq $0 // error code
	pushq $32
	jmp generic_exception_handler

.globl signal_int_handler
signal_int_handler:
	pushq $0 // error code
	pushq $33
	jmp generic_exception_handler

.globl syscall_entry
syscall_entry:
	swapgs
	movq %rsp, %gs:(16)
	movq %gs:(0), %rsp // load proc trapframe

	pushq $(SEGSEL_APP_DATA + 3)
	pushq %gs:(16)
	pushq %r11
	pushq $(SEGSEL_APP_CODE + 3)
	pushq %rcx

	subq $8, %rsp
	pushq $-1
	push %gs
	push %fs
	pushq %r15
	pushq %r14
	pushq %r13
	pushq %r12
	subq $8, %rsp
	pushq %r10
	pushq %r9
	pushq %r8
	pushq %rdi
	pushq %rsi
	pushq %rbp
	pushq %rbx
	pushq %rdx
	subq $8, %rsp
	pushq %rax

	movq %rsp, %rdi
	movq %gs:(8), %rsp // load kernel stack

	call syscall_amd64

.globl default_int_handler
default_int_handler:
	pushq $0
	jmp generic_exception_handler

generic_exception_handler:
	testb $3, 24(%rsp)
	jz kernel_exception_handler

user_exception_handler:
	swapgs
	movq %r15, %gs:(24) // scratch
	movq %rsp, %r15     // old rsp stored in r15
	movq %rsp, %gs:(16)
	movq %gs:(0), %rsp  // load proc trapframe

	// copy data from exception stack to trapframe
	pushq 48(%r15) // %ss
	pushq 40(%r15) // %rsp
	pushq 32(%r15) // %rflags
	pushq 24(%r15) // %cs
	pushq 16(%r15) // %rip
	pushq 8(%r15)  // error code
	pushq 0(%r15)  // interrupt number

	// restore r15
	movq %gs:(24), %r15

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

	// load kernel stack
	movq %gs:(8), %rsp
	call user_exception

kernel_exception_handler:
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
	call kernel_exception

.globl userret
userret:
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
	addq $8, %rsp
	// popq %fs
	swapgs
	popq %gs
	addq $16, %rsp
	iretq

.globl kswitch
kswitch:
	movq %rsp, 0x0(%rsi)
	movq %r15, 8(%rsi)
	movq %r14, 16(%rsi)
	movq %r13, 24(%rsi)
	movq %r12, 32(%rsi)
	movq %rbx, 40(%rsi)
	movq %rbp, 48(%rsi)

	movq 0(%rdx), %rsp
	movq 8(%rdx), %r15
	movq 16(%rdx), %r14
	movq 24(%rdx), %r13
	movq 32(%rdx), %r12
	movq 40(%rdx), %rbx
	movq 48(%rdx), %rbp
	movq %rdi, %rax
	ret

.bss

.globl exception_stack_end
exception_stack_start:
	.fill 0x8000,1,0
exception_stack_end:
