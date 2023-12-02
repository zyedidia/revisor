.text

.globl _start
_start:
	adr x8, init_stack_end
	mov sp, x8

	//mrs x0, cpacr_el1
	//orr x0, x0, #0x300000
	//msr cpacr_el1, x0
	//str d0, [sp, #-16]!
	//ldr x0, =0x84000008
	//hvc #0

	bl kinit
	bl __libc_init_array
	bl kmain
	bl __libc_fini_array
	bl exit
spin:
	wfi
	b spin

.section ".stack"

.align 16
.globl init_stack_end
init_stack_start:
	.fill 0x8000,1,0
init_stack_end:
