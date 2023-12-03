.text

.globl _start
_start:
	adr x8, init_stack_end
	mov sp, x8

	bl kinit
	bl __libc_init_array
	bl kmain
	bl __libc_fini_array
	bl exit
spin:
	wfi
	b spin

.section ".stack"

.p2align 4
.globl init_stack_end
init_stack_start:
	.fill 0x8000,1,0
init_stack_end:
