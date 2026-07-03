[BITS 64]

global get_sin
global get_cos

%include "common/sin_table.inc"
	

section .text
get_sin:
	mov eax, [sin_table + rdi*4] 
	ret
get_cos:
	add rdi, 0x40
	and rdi, 0xFF
	mov eax, [sin_table + rdi * 4]
	ret
