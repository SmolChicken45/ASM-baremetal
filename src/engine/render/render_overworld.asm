[BITS 64]
DEFAULT REL

global render_overworld_map
global render_overworld_entities
global render_overworld_ui

extern player_data
extern current_world_state
extern fb_draw_sprite

extern serial_write_qword

section .text

render_overworld_map:

    ret

render_overworld_entities:
    ; X
    movsxd rdi, dword [rel player_data]
    sar rdi, 8
    sub rdi, 10

    ; Y
    movsxd rsi, dword [rel player_data + 4]
    sar rsi, 8
    sub rsi, 37

    ; Pointeur vers l'image
    mov rdx, qword [rel player_data + 16]

    mov eax, dword [rel player_data + 24]
    imul eax, 53760

    mov ecx, dword [rel player_data + 28]
    imul ecx, 84
    add rax, rcx

    mov ecx, dword [rel current_world_state]
    imul ecx, 336
    add rax, rcx

    add rdx, rax

    ; Largeur
    movsxd rcx, dword [rel player_data + 8]
    
    ; Hauteur
    movsxd r8, dword [rel player_data + 12]

    ; Pitch
    mov r9, 336


    ; Dessiner
    call fb_draw_sprite


    ret

render_overworld_ui:

    ret
