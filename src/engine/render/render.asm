[BITS 64]

global render_frame

extern fb_clear
extern fb_draw_tile
extern fb_draw_sprite

extern render_map_hook
extern render_entities_hook
extern render_ui_hook


section .data

section .data
    color    dd 0x00000000
    phase    db 0
    val      db 0

section .text

change_color:
    movzx eax, byte [phase]
    cmp eax, 0
    je .phase0
    cmp eax, 1
    je .phase1
    cmp eax, 2
    je .phase2
    cmp eax, 3
    je .phase3
    cmp eax, 4
    je .phase4
    cmp eax, 5
    je .phase5
    cmp eax, 6
    je .phase6

.phase0:
    mov ebx, 0x00000000
    movzx ecx, byte [val]
    or ebx, ecx
    jmp .finish

.phase1:
    mov ebx, 0x000000FF
    movzx ecx, byte [val]
    shl ecx, 8
    or ebx, ecx
    jmp .finish

.phase2:
    mov ebx, 0x0000FF00
    mov eax, 255
    sub al, [val]
    or ebx, eax
    jmp .finish

.phase3:
    mov ebx, 0x0000FF00
    movzx ecx, byte [val]
    shl ecx, 16
    or ebx, ecx
    jmp .finish

.phase4:
    mov ebx, 0x00FF0000
    mov eax, 255
    sub al, [val]
    shl eax, 8
    or ebx, eax
    jmp .finish

.phase5:
    mov ebx, 0x00FF0000
    movzx ecx, byte [val]
    or ebx, ecx
    jmp .finish

.phase6:
    mov ebx, 0x000000FF
    mov eax, 255
    sub al, [val]
    shl eax, 16
    or ebx, eax

.finish:
    mov [color], ebx
    inc byte [val]
    cmp byte [val], 255
    jne .end
    mov byte [val], 0
    inc byte [phase]
    cmp byte [phase], 7
    jne .end
    mov byte [phase], 1
.end:
    ret


render_frame:

	;clear screen
    call change_color
    mov eax, [color]
	call fb_clear
	
	; draw
	call [render_map_hook]
	call [render_entities_hook]
	call [render_ui_hook]
	
	ret
	