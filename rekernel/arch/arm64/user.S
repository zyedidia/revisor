.text

// function: userret(Proc* p)
.globl userret
userret:
	// restore all registers
	ldp x2, x3,   [x0, #40+16*0]
	ldp x4, x5,   [x0, #40+16*1]
	ldp x6, x7,   [x0, #40+16*2]
	ldp x8, x9,   [x0, #40+16*3]
	ldp x10, x11, [x0, #40+16*4]
	ldp x12, x13, [x0, #40+16*5]
	ldp x14, x15, [x0, #40+16*6]
	ldp x16, x17, [x0, #40+16*7]
	ldp x18, x19, [x0, #40+16*8]
	ldp x20, x21, [x0, #40+16*9]
	ldp x22, x23, [x0, #40+16*10]
	ldp x24, x25, [x0, #40+16*11]
	ldp x26, x27, [x0, #40+16*12]
	ldp x28, x29, [x0, #40+16*13]
	ldp x30, x1,  [x0, #40+16*14]
	msr sp_el0, x1
	ldr x1,       [x0, #32]
	ldr x0,       [x0, #24]

	eret
