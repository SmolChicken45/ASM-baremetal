[BITS 64]
DEFAULT REL

extern init_video
extern render_frame
extern present_frame
extern update_input
extern init_idt
extern set_present_background
extern detect_cdrom
extern load_file
extern memory_init
extern init_audio_system

extern system_ticks

extern serial_write_byte
extern serial_init

section .rodata

border_filename: db "ASSETS/BORDER.RAW;1", 0

section .text
global _start

_start:

    call serial_init

    mov al, 0x53
    call serial_write_byte

    mov al, 0x43
    call serial_write_byte
    
    mov al, 0x34
    call serial_write_byte

    mov al, 0x35
    call serial_write_byte


    call init_video
    call init_audio_system
    call memory_init


	; Détecter le CD Rom
	call detect_cdrom
    test rax, rax
    jz .halt

    call init_idt
    sti


    lea rdi, [rel border_filename]
    call load_file
    mov rdi, rax
    call set_present_background

.game_loop:
    mov r15, [system_ticks]

    call update_input


    call render_frame
    call present_frame

.wait_vblank:
    cmp r15, [system_ticks]
    jne .game_loop

    hlt
    jmp .wait_vblank


.halt:
    hlt
    jmp .halt
