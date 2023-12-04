// _hypercall(a0, a1, a2, num)
.globl _hypercall
_hypercall:
	lea hypcall_dev, %r8
	mov (%r8), %r8
	mov %rcx, %rax
	mov %rax, (%r8)
	ret
