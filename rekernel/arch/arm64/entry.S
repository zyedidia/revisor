.text

.globl _start
_start:
	adr x8, init_stack_end
	mov sp, x8
	bl kinit
	mov x0, #0
	str d0, [x0]
	//bl kmain
	bl exit
spin:
	b spin

.bss

.align 16
.globl init_stack_end
init_stack_start:
	.fill 0x8000,1,0
init_stack_end:
