.text

// Save all registers so that the trap handler can inspect them on the stack.
.macro PROLOGUE
sub sp, sp, #256
stp x0, x1,   [sp, #0+16*0]
stp x2, x3,   [sp, #0+16*1]
stp x4, x5,   [sp, #0+16*2]
stp x6, x7,   [sp, #0+16*3]
stp x8, x9,   [sp, #0+16*4]
stp x10, x11, [sp, #0+16*5]
stp x12, x13, [sp, #0+16*6]
stp x14, x15, [sp, #0+16*7]
stp x16, x17, [sp, #0+16*8]
stp x18, x19, [sp, #0+16*9]
stp x20, x21, [sp, #0+16*10]
stp x22, x23, [sp, #0+16*11]
stp x24, x25, [sp, #0+16*12]
stp x26, x27, [sp, #0+16*13]
stp x28, x29, [sp, #0+16*14]
stp x30, xzr, [sp, #0+16*15]
.endm

// Only need to restore caller-saved registers

.macro EPILOGUE
ldp x0, x1,   [sp, #0+16*0]
ldp x2, x3,   [sp, #0+16*1]
ldp x4, x5,   [sp, #0+16*2]
ldp x6, x7,   [sp, #0+16*3]
ldp x8, x9,   [sp, #0+16*4]
ldp x10, x11, [sp, #0+16*5]
ldp x12, x13, [sp, #0+16*6]
ldp x14, x15, [sp, #0+16*7]
ldp x16, x17, [sp, #0+16*8]
ldr x18,      [sp, #0+16*9]
ldp x29, x30, [sp, #0+16*14+8]
add sp, sp, #256
eret
.endm

.globl ktrap_entry
.balign 2048
ktrap_entry:
cur_el_sp0_sync:
	b .
.balign 0x80
cur_el_sp0_irq:
	b .
.balign 0x80
cur_el_sp0_fiq:
	b .
.balign 0x80
cur_el_sp0_serror:
	b .
.balign 0x80
cur_el_spx_sync:
	b exception_entry
.balign 0x80
cur_el_spx_irq:
	b interrupt_entry
.balign 0x80
cur_el_spx_fiq:
	b interrupt_entry
.balign 0x80
cur_el_spx_serror:
	b exception_entry
.balign 0x80
lower_el_aarch64_sync:
	b user_exception
.balign 0x80
lower_el_aarch64_irq:
	b user_interrupt
.balign 0x80
lower_el_aarch64_fiq:
	b user_interrupt
.balign 0x80
lower_el_aarch64_serror:
	b user_exception
// aarch32 stuff, just infinite loop
.balign 0x80
	b .
.balign 0x80
	b .
.balign 0x80
	b .
.balign 0x80
	b .

exception_entry:
	PROLOGUE
	mov x0, sp
	bl kernel_exception
	EPILOGUE

interrupt_entry:
	PROLOGUE
	mov x0, sp
	bl kernel_interrupt
	EPILOGUE