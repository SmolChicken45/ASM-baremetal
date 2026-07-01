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
extern find_file

extern system_ticks

extern get_framebuffer_response
extern module_request


section .rodata

stats_filename: db "STATS.DAT;1", 0

section .text
global _start

_start:

   ; Valider la présence de l'écran
    mov rax, [get_framebuffer_response]
    test rax, rax
    jz .halt

    call init_video
    call get_audio_device


	; Détecter le CD Rom
	call detect_cdrom
    test rax, rax
    jz .halt

    lea rdi, [rel stats_filename]
    call find_file

    test rax, rax
    jz .halt

    call init_idt
    sti

    

    mov rax, [module_request + 40]
    test rax, rax
    jz .halt

    mov rcx, [rax + 8]
    test rcx, rcx
    jz .halt

    mov rbx, [rax + 16]
    mov rbx, [rbx]
    mov rdi, [rbx + 8]

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
