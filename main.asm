[BITS 64]
DEFAULT REL

extern get_audio_device
extern init_video
extern render_frame
extern present_frame
extern update_input
extern init_idt
extern set_present_background
extern detect_cdrom
extern load_file
extern memory_init

extern system_ticks

extern get_framebuffer_response


section .rodata

border_filename: db "ASSETS/BORDER.RAW;1", 0

section .text
global _start

_start:

   ; Valider la présence de l'écran
    mov rax, [get_framebuffer_response]
    test rax, rax
    jz .halt

    call init_video
    call get_audio_device
    call memory_init

    test rax,rax
    jz .halt

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
