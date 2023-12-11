#define TCR_T0SZ   (16 << 0)
#define TCR_T1SZ   (16 << 16)
#define TCR_IPS48  (0b101 << 32)
#define TCR_TG0_4K (0b00 << 14)
#define TCR_TG1_4K (0b10 << 30)
#define TCR_IRG    (0b01 << 8) | (0b01 << 24)
#define TCR_ORG    (0b01 << 10) | (0b01 << 26)
#define TCR_SH     (0b11 << 12) | (0b11 << 28)

#define TCR (TCR_T0SZ | TCR_T1SZ | TCR_IPS48 | TCR_TG0_4K | TCR_TG1_4K | TCR_IRG | TCR_ORG | TCR_SH)

.section ".lowtext", "ax"

.globl _start
_start:
	// x0: memory size
	// x1: argc
	// x2: argv

	ldr x4, =TCR
	msr tcr_el1, x4
	ldr x4, =0xff
	msr mair_el1, x4
	adr x3, l0pt
	msr ttbr0_el1, x3
	msr ttbr1_el1, x3

	mrs x3, sctlr_el1
	orr x3, x3, #(0x1 << 2)  // dcache
	orr x3, x3, #(0x1 << 12) // icache
	orr x3, x3, #0x1         // mmu
	msr sctlr_el1, x3
	dsb sy
	isb

	ldr x3, =_start64
	br x3

.section ".lowdata", "a"

.p2align 12
l0pt:
	.quad l1pt + 3
	.fill 511,8,0

.p2align 12
l1pt:
	.quad 0x00000705
	.quad 0x40000701
	.quad 0x80000701
	.fill 509,8,0

.text

_start64:
	// disable the lower half pagetable
	msr ttbr0_el1, xzr
	isb

	adr x8, init_stack_end
	mov sp, x8

	// save x1 and x2 (argc and argv)
	mov x21, x1
	mov x22, x2

	bl kinit
	bl __libc_init_array
	mov x0, x21
	mov x1, x22
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
