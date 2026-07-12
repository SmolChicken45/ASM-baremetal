[BITS 64]
DEFAULT REL

global draw_layout

extern fb_draw_sprite

section .text

; draw_layout
;
; rdi = atlas pointer
; rsi = layout pointer
; rdx = spritesheet pixel pointer
; rcx = spritesheet pitch in pixels
;
; Layout entry:
;   dw object_id, pos_x, pos_y
;
; Atlas entry:
;   db src_x, src_y, width, height, origin_x, origin_y
;
; Stops when object_id == 0xFFFF

draw_layout:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15

    ; Align stack before calls
    sub rsp, 8

    mov r12, rdi        ; atlas pointer
    mov r13, rsi        ; layout pointer
    mov r14, rdx        ; spritesheet pixels
    mov r15, rcx        ; spritesheet pitch

.loop:
    ; read object id
    movzx eax, word [r13]

    cmp ax, 0xFFFF
    je .done

    ; Atlas entry address = atlas + object_id * 6
    mov ebx, eax
    imul rbx, 6
    lea rbp, [r12 + rbx]

    ; read layout position
    movzx ebx, word [r13 + 2]    ; pos_x
    movzx ecx, word [r13 + 4]    ; pos_y

    ; read atlas data.
    movzx eax, byte [rbp + 0]    ; src_x
    movzx edx, byte [rbp + 1]    ; src_y
    movzx r8d, byte [rbp + 2]    ; width
    movzx r9d, byte [rbp + 3]    ; height

    ; Apply origin offset
    ; screen_x = pos_x - origin_x
    ; screen_y = pos_y - origin_y
    movzx esi, byte [rbp + 4]    ; origin_x
    ; add ebx, esi

    movzx esi, byte [rbp + 5]    ; origin_y
    ; add ecx, esi

    ; compute sprite pointer:
    ; sprite_ptr = spritesheet + ((src_y * pitch) + src_x) * 4
    imul rdx, r15
    add rdx, rax
    shl rdx, 2
    add rdx, r14

    ; Call fb_draw_sprite:
    ; rdi = screen_x
    ; rsi = screen_y
    ; rdx = sprite pointer
    ; rcx = width
    ; r8 = height
    ; r9 = sheet pitch
    movsxd rdi, ebx
    movsxd rsi, ecx
    mov rcx, r8
    mov r8, r9
    mov r9, r15
    
    call fb_draw_sprite

    ; Next layout entry: 3 words = 6 bytes
    add r13, 6
    jmp .loop

.done:
    add rsp, 8
    
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret
