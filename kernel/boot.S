#define ASM
#include "boot.h"

.text

.globl  kmain

.code64

.globl bootstrap, init_pml4, init_pdp, init_pd
bootstrap:
	/* make sure interrupts are off */
	cli

	/* load the GDT */
	lgdt (init_gdt64_ptr - KERNEL_VMA)

	/* give ourselves a functional stack */
	movl $(init_stack_end - KERNEL_VMA), %esp

	/* load a level4 PD */
	movq    $(init_pml4 - KERNEL_VMA), %rax
	mov     %rax, %cr3

boot64:
	/* do an indirect to force non-relative jmp */
	movabsq $boot64_high, %rax
	jmp *%rax


.code64
boot64_high:
	/* adjust the stack pointer to be in upper memory */
	movq $KERNEL_VMA, %rax
	addq %rax, %rsp
	
	/* unmap the kernel from low memory */
	movq   $0x0,init_pml4
	invlpg 0

	/* go to our C entry point */
	call kinit
	call kmain

boot64_hang:
	hlt
	jmp boot64_hang

.data
.align 16
gdt64:
	.quad 0x0000000000000000 // 0x00 NULL
	.quad 0x0020980000000000 // 0x08 KCODE64
gdt64_end:

.align 16
init_gdt64_ptr:
	.word gdt64_end - gdt64 - 1
	.long gdt64 - KERNEL_VMA

/* ident map of first 4MB GB, and mirror it at the -2GB mark  */
.align 0x1000
init_pml4:
	.quad init_pdp - KERNEL_VMA + 3 // [0x0000000000000000 - 0x00000007ffffffff)
	.fill 510,8,0
	.quad init_pdp - KERNEL_VMA + 3 // [0xfffffff800000000 - 0xffffffffffffffff)

init_pdp:
	.quad init_pd - KERNEL_VMA + 3
	.fill 509,8,0
	.quad init_pd - KERNEL_VMA + 3
	.fill 1,8,0

init_pd:
	.quad 0x0000000000000083 // 0MB - 2MB
	.quad 0x0000000000200083 // 2MB - 4MB
	.fill 510,8,0


init_stack_start:
	.fill 0x8000,1,0
init_stack_end:
