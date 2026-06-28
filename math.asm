[BITS 64]

global get_sin
global get_cos

section .rodata
align 16

sin_table:
	dd 0
	dd 25
	dd 50
	dd 75
	

section .text
get_sin:
	mov eax, [sin_table + rdi*4] 
	ret
get_cos:
	add rdi, 0x40
	and rdi, 0xFF
	mov eax, [sin_table + rdi*]
	ret
