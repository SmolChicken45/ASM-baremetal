[BITS 64]
DEFAULT REL

global render_overworld_map
global render_overworld_entities
global render_overworld_ui

extern player_data
extern fb_draw_sprite

extern serial_write_qword

section .text

render_overworld_map:

    ret

render_overworld_entities:
    ; X
    movsxd rdi, dword [rel player_data]
    sub rdi, 10

    ; Y
    movsxd rsi, dword [rel player_data + 4]
    sub rsi, 37

    ; Pointeur vers l'image
    mov rdx, qword [rel player_data + 16]

    add rdx, 53760

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
