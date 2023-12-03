.section ".lowtext", "ax"

.globl _start
_start:
	ldr x1, =0xb5193519
	msr tcr_el1, x1
	ldr x1, =0xff
	msr mair_el1, x1
	adr x0, pagetable
	msr ttbr0_el1, x0
	msr ttbr1_el1, x0

	mrs x0, sctlr_el1
	orr x0, x0, #(0x1 << 2)  // dcache
	orr x0, x0, #(0x1 << 12) // icache
	orr x0, x0, #0x1         // mmu
	msr sctlr_el1, x0
	dsb sy
	isb

	ldr x0, =_start64
	br x0

.section ".lowdata", "a"

.p2align 12
.globl pagetable
pagetable:
	.quad 0x00000705
	.quad 0x40000701
	.fill 254,8,0
	.quad 0x00000705
	.quad 0x40000701
	.fill 254,8,0

.text

_start64:
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

.data

.p2align 4
.globl init_stack_end
init_stack_start:
	.fill 0x8000,1,0
init_stack_end:
