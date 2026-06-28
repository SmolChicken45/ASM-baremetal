[BITS 64]

global present_frame
global swap_buffers
global current_back_buffer
global current_front_buffer

extern limine_framebuffer_addr

section .bss
align 16

framebuffer_back:
	resb FB_Width * FB_HEIGHT * FB_BPP
	
framebuffer_front:
	resb FB_Width * FB_HEIGHT * FB_BPP
	
section .data
	current_back_buffer		dq framebuffer_back
	current_front_buffer	dq framebuffer_front
	
	
section .text

swap_buffers:
	
	mov rax, [current_back_buffer]
	mov rdx, [current_front_buffer]
	
	mov [current_back_buffer], rdx
	mov [current_front_buffer], rax
	
	ret
	
present_frame:

	call swap_buffers
	
	mov rdi, [current_front_buffer]
	mov rsi, [limine_framebuffer_addr]
	
	call upscale_and_copy
	
upscale_and_copy:
	; TODO implement
	ret