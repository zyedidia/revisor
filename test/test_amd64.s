.code32

.globl _start
_start:
	mov %edi, %ecx
	mov $0, %eax
	mov $1, %edi
	lea s, %esi
	mov $12, %edx
	mov %eax, (%ecx)
	// exit
	mov $1, %eax
	mov %eax, (%ecx)

s:
	.asciz "hello world\n"
