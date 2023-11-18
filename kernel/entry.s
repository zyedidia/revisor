.section ".text.boot"

.globl kernel_entry
kernel_entry:
	lgdt gdtdesc

	mov $_stack_high, %rsp
	call kernel_init
	call kernel_main
	hlt

# Segment descriptors
        .code32
        .p2align 2                           # force 4 byte alignment
gdt:    .word 0, 0, 0, 0                     # null
        .word 0, 0; .byte 0, 0x98, 0x20, 0   # code seg
		.word 0, 0, 0, 0
gdtdesc:
        .word 0x0f                           # sizeof(gdt) - 1
        .long gdt                            # address gdt
        .long 0
