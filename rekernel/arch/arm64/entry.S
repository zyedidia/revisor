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
	ldr x1, =TCR
	msr tcr_el1, x1
	ldr x1, =0xff
	msr mair_el1, x1
	adr x0, l0pt
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
l0pt:
	.quad l1pt + 3
	.fill 255,8,0
	.quad l1pt + 3
	.fill 255,8,0

.p2align 12
l1pt:
	.quad 0x00000705
	.quad 0x40000701
	.fill 510,8,0

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
