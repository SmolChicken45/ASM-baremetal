[BITS 64]

global render_frame

extern fb_clear
extern fb_draw_tile
extern fb_draw_sprite



section .data

section .data
    color    dd 0x00000000
    phase    db 0
    val      db 0

render_camera:
	dq 0	; x
	dq 0	; y

render_player:
	dd 0	; x
	dd 0	; y
	dd 0	; width
	dd 0	; height
	dq 0	; sprite ptr
	
room_id 	dd 0
game_state	dd 0

section .bss

MAX_ENTITES		equ 128
ENTITY_X		equ 0
ENTITY_Y		equ 4
ENTITY_WIDTH	equ 8
ENTITY_HEIGHT	equ 12
ENTITY_SPRITE	equ 16
ENTITY_PADDING	equ 24
ENTITY_SIZE		equ 32

entity_count:
	resd 1
	
entities:
	resb MAX_ENTITES * ENTITY_SIZE


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
	call render_map
	call render_entities
	call render_ui
	
	ret
	
render_map:
	;    TODO: draw room tils here later
    ret
	
render_entities:
    ; TODO: draw player/ennemies here later
    ret

render_ui:
    ; TODO: draw UI here later
    ret
    