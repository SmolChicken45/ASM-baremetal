[BITS 64]

%include "screen.inc"

global fb_set_pixel
global fb_clear
global fb_get_buffer
global fb_draw_tile
global fb_draw_sprite

extern current_back_buffer
	
section .text

fb_set_pixel:
	
	; rdi = x
	; rsi = y
	; edx = color 
	
	cmp rdi, 0
	jl .out
	cmp rdi, FB_WIDTH
	jae .out
	
	cmp rsi, 0
	jl .out
	cmp rsi, FB_HEIGHT
	jae .out
	
	
	mov rax, rsi
	imul rax, FB_WIDTH
	add rax, rdi
	shl rax, 2
	
	mov r8, [current_back_buffer]
	mov dword [r8 + rax], edx
	
.out:
	ret
	
fb_clear:

	; eax = color 
	
	mov rdx, rax
	shl rdx, 32
	or rax, rdx
	
	mov rdi, [current_back_buffer]
	mov rcx, FB_WIDTH * FB_HEIGHT / 2
	
	cld
	rep stosq
	
	ret
	
fb_get_buffer:
	mov rax, [current_back_buffer]
	ret

fb_draw_tile:

	; rdi = px
	; rsi = py
	; rdx = tile pointer (20x20 px, 32-bits)
	
	push rbx
	push r12
	push r13
	push r14
	push r15
	
	mov r12, rdi
	mov r13, rsi
	mov r14, rdx
	
	xor r8, r8
	
.tile_y_loop:
	cmp r8, 20
	jge .done
	
	mov r9, r13
	add r9, r8
	
	cmp r9, 0
	jl .next_row
	
	cmp r9, FB_HEIGHT
	jge .next_row
	
	xor r10, r10
	
.tile_x_loop:
	cmp r10, 20
	jge .next_row
	
	mov r11, r12
	add r11, r10
	
	cmp r11, 0
	jl .skip_pixel
	
	cmp r11, FB_WIDTH
	jge .skip_pixel
	
	mov rax, r8
	imul rax, 20
	add rax, r10
	shl rax, 2
	
	mov eax, [r14 + rax]
	
	test eax, eax
	jz .skip_pixel
	
	mov rbx, r9
	imul rbx, FB_WIDTH
	add rbx, r11
	shl rbx, 2
	
	mov r15, [current_back_buffer]
	mov dword [r15 + rbx], eax
	
.skip_pixel:
	inc r10
	jmp .tile_x_loop
	
.next_row:
	inc r8
	jmp .tile_y_loop
	
.done:
	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx
	ret
	

fb_draw_sprite:

	; rdi = screen_x
	; rsi = screen_y
	; rdx = sprite pointer (pixels 32-bit)
	; rcx = width
	; r8  = heights

	
	push rbx
	push r12
	push r13
	push r14
	push r15
	
	mov r12, rdi
	mov r13, rsi
	mov r14, rdx
	mov r15, rcx
	
	mov rdx, [current_back_buffer]
	xor r9, r9
	
.y_loop:
	cmp r9, r8
	jge .done
	
	mov r10, r13
	add r10, r9
	
	cmp r10, 0
	jl .next_row
	
	xor r11, r11
	
.x_loop:
	cmp r11, r15
	jge .next_row
	
	mov rax, r12
	add rax, r11
	
	cmp rax, 0
	jl .skip_pixel
	
	cmp rax, FB_WIDTH
	jge .skip_pixel
	
	mov rbx, r9
	imul rbx, r15
	add rbx, r11
	shl rbx, 2
	
	mov eax, [r14 + rbx]
	
	test eax, eax
	jz .skip_pixel
	
	mov rbx, r10
	imul rbx, FB_WIDTH
	add rbx, r11
	shl rbx, 2
	
	mov dword [rdx + rbx], eax
	
.skip_pixel:
	inc r11
	jmp .x_loop
	
.next_row:
	inc r9
	jmp .y_loop
	
.done:
	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx
	ret
