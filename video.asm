[BITS 64]
%include "screen.inc"

global present_frame
global swap_buffers
global current_back_buffer
global current_front_buffer
global set_present_background

extern SCR_address
extern SCR_width
extern SCR_height
extern SCR_pitch

section .bss
align 16

framebuffer_back:
	resb FB_WIDTH * FB_HEIGHT * FB_BPP
	
framebuffer_front:
	resb FB_WIDTH * FB_HEIGHT * FB_BPP
	
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

set_present_background:
    ; ------------------------------------------------------------
    ; set_present_background
    ;
    ; rdi = pointer vers une image 1920x1080 en 32 bpp
    ;
    ; Copie l'image directement dans le framebuffer écran une seule fois.
    ; L'image n'est pas redessinée à chaque frame.
    ; ------------------------------------------------------------

    push rbp
    mov rbp, rsp

    push rbx
	push r12
	push r13
	push r14
	push r15

    cmp rdi, 0
    je .done

    mov rsi, [SCR_address]
    cmp rsi, 0
    je .done

    mov rax, [SCR_width]
    cmp rax, 1920
    jb .done
    
    mov rax, [SCR_height]
    cmp rax, 1080
    jb .done

    mov rbx, [SCR_pitch]
    cmp rbx, 0
    je .done

    ; rdi = source image
	; rsi = destination framebuffer
	; rbx = destination pitch en bytes

    xor r12, r12

.row_loop:
    cmp r12, 1080
    jae .finished_copy

    ; r13 = source row = image + y * 1920 * 4
    mov r13, r12
    imul r13, 1920 * 4
    add r13, rdi

    ; r14 = destination row = SCR_address + y * SCR_pitch
    mov r14, r12
    imul r14, rbx
    add r14, rsi

    mov rcx, 960
    mov r15, r13

.copy_row_qwords:
    mov rax, [r15]
    mov [r14], rax
    add r15, 8
    add r14, 8
    loop .copy_row_qwords

    inc r12
    jmp .row_loop

.finished_copy:
.done:
    pop r15
	pop r14
	pop r13
	pop r12
	pop rbx

	pop rbp
	ret
	
present_frame:

	call swap_buffers
	
	mov rdi, [current_front_buffer]
	mov rsi, [SCR_address]
	
	call upscale_and_copy
	
upscale_and_copy:
    ; rdi = source framebuffer, 320x240, 32-bit pixels
    ; rsi = destination screen framebuffer
    ;
    ; Integer aspect-ratio scaling with letterboxing.
    ;
    ; Stack locals:
    ; [rbp - 48]  = src_ptr
    ; [rbp - 56]  = dst_ptr
    ; [rbp - 64]  = screen_width
    ; [rbp - 72]  = screen_height
    ; [rbp - 80]  = screen_pitch
    ; [rbp - 88]  = scale
    ; [rbp - 96]  = offset_x
    ; [rbp - 104] = offset_y

    push rbp
    mov rbp, rsp

    push rbx
    push r12
    push r13
    push r14
    push r15

    sub rsp, 64

    mov [rbp - 48], rdi    ; source buffer
    mov [rbp - 56], rsi    ; destination framebuffer

    mov rax, [SCR_width]    
    mov [rbp - 64], rax    ; screen width

    mov rax, [SCR_height]    
    mov [rbp - 72], rax    ; screen height

    mov rax, [SCR_pitch]    ; screen pitch in bytes
    mov [rbp - 80], rax    ; screen pitch

    cmp qword [rbp - 48], 0
    je .done

    cmp qword [rbp - 56], 0
    je .done

    cmp qword [rbp - 64], 0
    je .done

    cmp qword [rbp - 72], 0
    je .done

    cmp qword [rbp - 80], 0
    je .done

    ; scale_x = SCR_width / FB_WIDTH
    mov rax, [rbp - 64]    ; screen_width
    xor rdx, rdx
    mov rcx, FB_WIDTH
    div rcx                ; rax = scale_x
    mov r8, rax            ; r8 = scale_x


    ; scale_y = SCR_height / FB_HEIGHT
    mov rax, [rbp - 72]    ; screen_height
    xor rdx, rdx
    mov rcx, FB_HEIGHT
    div rcx                ; rax = scale_y


    ; scale = min(scale_x, scale_y)
    cmp r8, rax
    cmova r8, rax          ; r8 = min (scale_x, scale_y)

    test r8, r8
    jnz .scale_ok
    ; If the real screen is smaller than the local framebuffer,
    ; force scale to 1. This can crop, but avoids scale = 0.
    mov r8, 1 

.scale_ok:

    mov [rbp - 88], r8    ; scale

   
    ; ------------------------------------------------------------
    ; offset_x = (screen_width - FB_WIDTH * scale) / 2
    ; offset_y = (screen_height - FB_HEIGHT * scale) / 2
    ; ------------------------------------------------------------

    mov rax, FB_WIDTH
    imul rax, [rbp - 88]    ; scaled_width
    mov rbx, [rbp - 64]     ; screen_width
    sub rbx, rax
    shr rbx, 1
    mov [rbp - 96], rbx     ; offset_x

    mov rax, FB_HEIGHT
    imul rax, [rbp - 88]    ; scaled_height
    mov rbx, [rbp - 72]     ; screen_height
    sub rbx, rax
    shr rbx, 1
    mov [rbp - 104], rbx    ; offset_y

    ; ------------------------------------------------------------
    ; Draw scaled framebuffer.
    ;
    ; for src_y in FB_HEIGHT:
    ;   for src_x in FB_WIDTH:
    ;       pixel = src[src_y * FB_WIDTH + src_x]
    ;
    ;       dest_base_x = offset_x + src_x * scale
    ;       dest_base_y = offset_y + src_y * scale
    ;
    ;       for block_y in scale:
    ;           row = dst + (dest_base_y + block_y) * pitch
    ;           for block_x in scale:
    ;               row[dest_base_x + block_x] = pixel
    ; ------------------------------------------------------------


    xor r8, r8            ; source y = 0

.src_y_loop:
    cmp r8, FB_HEIGHT
    jae .done

    ; r12 = source row pointer
    mov rax, r8
    imul rax, FB_WIDTH * FB_BPP
    mov r12, [rbp - 48]
    add r12, rax


    xor r9, r9            ; source x = 0

.src_x_loop:
    cmp r9, FB_WIDTH
    jae .next_src_row

    ; Load source pixel
    mov r15d, [r12 + r9 * 4]

    ; r14 = dest_base_x = offset_x + source_x * scale
    mov r14, r9
    imul r14, [rbp - 88]     
    add r14, [rbp - 96]

    ; r10 = dest_base_y = offset_y + source_y * scale
    mov r10, r8
    imul r10, [rbp - 88]
    add r10, [rbp - 104]

    xor r11, r11       ; block y = 0

.block_y_loop:
    cmp r11, [rbp - 88]
    jae .next_src_pixel

    ; r13 = destination row pointer
    mov rax, r10
    add rax, r11            ; dest_y = dest_base_y + block_y
    imul rax, [rbp - 80]    ; dest_y * pitch
    mov r13, [rbp - 56]
    add r13, rax    ; r13 = row pointer

    xor rcx, rcx            ; block x = 0

.block_x_loop:
    cmp rcx, [rbp - 88]
    jae .next_block_row
    
    ; rax = dest_x = dest_base_x + block_x
    mov rax, r14
    add rax, rcx

    mov [r13 +  rax * 4], r15d

    inc rcx
    jmp .block_x_loop

.next_block_row:
    inc r11
    jmp .block_y_loop

.next_src_pixel:
    inc r9
    jmp .src_x_loop

.next_src_row:
    inc r8
    jmp .src_y_loop

.done:
    add rsp, 64

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx

    pop rbp
	ret