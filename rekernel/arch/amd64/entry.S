.section ".lowtext", "ax"

.code32

.globl _start
_start:
	/* make sure interrupts are off */
	cli

	/* load the GDT */
	lgdt init_gdt64_ptr

	/* ensure that paging is off */
	movl    %cr0, %eax
	andl    $0x7fffffff, %eax
	movl    %eax, %cr0

	/* enable CR4.PAE */
	movl    %cr4, %eax
	orl     $0x20, %eax
	movl    %eax, %cr4

	/* load a level4 PD */
	movl    $init_pml4, %eax
	mov     %eax, %cr3

	/* set IA32_EFER.LME */
	movl    $0xc0000080, %ecx
	rdmsr
	/* set the PAE and SYSENTER bits */
	orl     $0x00000101, %eax
	wrmsr

	/* enable paging */
	movl    %cr0, %eax
	orl     $0x80000000, %eax
	movl    %eax, %cr0

	/* at this point we should be in IA-32e mode */
	ljmp $0x08, $boot64

.code64

boot64:
	/* do an indirect to force non-relative jmp */
	movabsq $boot64_high, %rax
	jmp *%rax

.section ".lowdata", "a"

.align 16
gdt64:
	.quad 0x0000000000000000 // 0x00 NULL
	.quad 0x0020980000000000 // 0x08 KCODE64
gdt64_end:

.align 16
init_gdt64_ptr:
	.word gdt64_end - gdt64 - 1
	.long gdt64

.align 0x1000
init_pml4:
	.quad init_pdp + 3       // [0x0000000000000000 - 0x00000007ffffffff)
	.fill 255,8,0
	.quad init_pdp + 3       // [0xffff800000000000 - 0xffff8007ffffffff)
	.fill 254,8,0
	.quad init_pdp_upper + 3 // [0xffffffff80000000 - 0xffffffffffffffff)

// kernel text
.globl init_pdp_upper
.align 0x1000
init_pdp_upper:
	.fill 510,8,0
	.quad 0x0000000000000083 // 0GB - 1GB, PS, RW, P
	.quad 0x0000000040000083 // 1GB - 2GB, PS, RW, P

// kernel data
.globl init_pdp
.align 0x1000
init_pdp:
	.quad 0x0000000000000083 // 0GB - 1GB, PS, RW, P
	.quad 0x0000000040000083 // 1GB - 2GB, PS, RW, P
	.quad 0x0000000080000083 // 2GB - 3GB, PS, RW, P
	.quad 0x00000000c0000083 // 3GB - 4GB, PS, RW, P
	.quad 0x0000000100000083 // 4GB - 5GB, PS, RW, P
	.fill 507,8,0

.text

.code64
boot64_high:
	mov $init_stack_end, %rsp

	// save rsi and rdx (argc and argv)
	movq %rsi, %r14

	call kinit
	call __libc_init_array

	movq %r14, %rdi
	movq %r15, %rsi

	call kmain
	call __libc_fini_array
	call exit

boot64_hang:
	hlt
	jmp boot64_hang

.data

.section ".stack"

init_stack_start:
	.fill 0x8000,1,0
init_stack_end:
