[BITS 64]
DEFAULT REL

global update_player_logic

extern InputState
extern player_data

; Vitesse en virgule fixe : 1,5 pixels * 256 = 384
SPEED equ 384
UP_VALUE equ 9
LEFT_VALUE equ 7
DOWN_VALUE equ 10
RIGHT_VALUE equ 8
PLAYER_DIRECTION equ 24
PLAYER_X equ 0
PLAYER_Y equ 4

section .data

animation_timer    dd 0


section .text


; -------------------------------
; Fonction qui gère le mouvement de Kris
;
; Regarde InputState
;
; Écrit dans player_data
; -------------------------------
update_player_logic:
    mov r8d, -1
    mov r9d, -1 
    xor r11d, r11d

.check_up_move:
    cmp byte [rel InputState + UP_VALUE], 0
    jz .check_down_move
    ; Mouvement Haut
    sub dword [rel player_data + PLAYER_Y], SPEED
    mov r8d, 3
    mov r11d, 1
    jmp .check_left_move
    
.check_down_move:
    cmp byte [rel InputState + DOWN_VALUE], 0
    jz .check_left_move
    ; Mouvement Bas
    add dword [rel player_data + PLAYER_Y], SPEED
    mov r8d, 0
    mov r11d, 1

.check_left_move:
    cmp byte [rel InputState + LEFT_VALUE], 0
    jz .check_right_move
    ; Mouvement Gauche
    sub dword [rel player_data + PLAYER_X], SPEED
    mov r9d, 1
    mov r11d, 1
    jmp .determine_direction
    
.check_right_move:
    cmp byte [rel InputState + RIGHT_VALUE], 0
    jz .determine_direction
    ; Mouvement Droite
    add dword [rel player_data + PLAYER_X], SPEED
    mov r9d, 2
    mov r11d, 1
    
    
.determine_direction:
    test r11d, r11d
    jz .idle
    
    mov eax, dword [rel player_data + PLAYER_DIRECTION]

    cmp eax, r8d
    je .update_animation
    
    cmp eax, r9d
    je .update_animation
    
    ; Direction actuelle n'est plus la bonne
    
.try_up:
    cmp r8d, 3
    jne .try_left
    mov dword [rel player_data + PLAYER_DIRECTION], 3
    jmp .update_animation
    
.try_left:
    cmp r9d, 1
    jne .try_down
    mov dword [rel player_data + PLAYER_DIRECTION], 1
    jmp .update_animation
    
.try_down:
    cmp r8d, 0
    jne .try_right
    mov dword [rel player_data + PLAYER_DIRECTION], 0
    jmp .update_animation
    
.try_right:
    mov dword [rel player_data + PLAYER_DIRECTION], 2


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