[BITS 64]
DEFAULT REL

global update_player_logic

extern InputState
extern player_data

; Vitesse en virgule fixe : 1,5 pixels * 256 = 384
SPEED equ 384

section .data

animation_timer    dd 0


section .text

update_player_logic:

    xor r11d, r11d

.check_left:
    ; left_value = + 7
    cmp byte [rel InputState + 7], 0
    jz .check_right
    ; MOuvement Gauche
    mov dword [rel player_data + 24], 1
    sub dword [rel player_data], SPEED
    mov r11d, 1
    jmp .check_vertical

.check_right:
    ; right_value = + 8
    cmp byte [rel InputState + 8], 0
    jz .check_vertical
    ; Mouvement Droite
    mov dword [rel player_data + 24], 2
    add dword [rel player_data], SPEED
    mov r11d, 1

    ; --- AXE VERTICAL ---
.check_vertical:
.check_up:
    ; up_value = + 9
    cmp byte [rel InputState + 9], 0
    jz .check_down
    ; Mouvement Haut
    mov dword [rel player_data + 24], 3
    sub dword [rel player_data + 4], SPEED
    mov r11d, 1
    jmp .update_animation


.check_down:
    ; down_value = + 10
    cmp byte [rel InputState + 10], 0
    jz .update_animation
    ; Mouvement Bas
    mov dword [rel player_data + 24], 0
    add dword [rel player_data + 4], SPEED
    mov r11d, 1

.update_animation:
    test r11d, r11d
    jz .idle

.moving:
    mov eax, dword [rel animation_timer]
    inc eax
    cmp eax, 4
    jl .save_timer

    xor eax, eax
    mov ecx, dword [rel player_data + 28]
    inc ecx
    
    and ecx, 3
    mov dword [rel player_data + 28], ecx

.save_timer:
    mov dword [rel animation_timer], eax
    ret

.idle:
    mov dword [rel player_data + 28], 0
    mov dword [rel animation_timer], 0

.done:
    ret