[BITS 64]
DEFAULT REL

extern set_present_background
extern load_file

extern system_ticks

extern boot_init
extern boot_halt

extern game_loop

extern player_data
extern tileset_ptr
extern current_map_ptr
extern update_player_logic
extern layout_ptr

section .rodata

border_filename: db "ASSETS/BORDER.RAW;1", 0
kris_walk_filename: db "ASSETS/KRISWALK.RAW;1", 0
kris_bedroom_tile_filename: db "ASSETS/KRIS_BED.RAW;1", 0
kris_bedroom_id_filename: db "ASSETS/KRIS_BED.BIN;1", 0
kris_bedroom_furniture_filename: db "ASSETS/KRIS_FUR.RAW;1", 0

section .text
global _start

_start:

    call boot_init
    test rax, rax
    jz .halt






    lea rdi, [rel border_filename]
    call load_file
    mov rdi, rax
    ; call set_present_background

    lea rdi, [rel kris_walk_filename]
    call load_file
    mov [player_data + 16], rax

	lea rdi, [rel kris_bedroom_tile_filename]
	call load_file
	mov [tileset_ptr], rax

	lea rdi, [rel kris_bedroom_id_filename]
	call load_file
	mov [current_map_ptr], rax

    lea rdi, [rel kris_bedroom_furniture_filename]
    call load_file
    mov [layout_ptr], rax

    jmp game_loop



.halt:
    call boot_halt
