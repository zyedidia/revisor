// hypercall(a0, a1, a2, num, hypcall_dev)
.globl hypercall
hypercall:
	adr x9, hypcall_dev
	ldr x9, [x9]
	mov x8, x3
	str xzr, [x9]
	ret
