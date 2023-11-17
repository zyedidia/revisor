.section ".text.boot"

.globl kernel_entry
kernel_entry:
	mov $_stack_high, %rsp
	call kernel_main
	hlt
