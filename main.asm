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
extern read_cdrom_sector

extern system_ticks

section .limine_reqs progbits alloc noexec write
align 8
    dq framebuffer_request
    dq module_request
    dq 0

section .data
align 8
framebuffer_request:
    dq 0xc7b1dd30df4c8b88
    dq 0x0a82e883a194f07b
    dq 0x9d5827dcd881dd75
    dq 0xa3148604f6fab11b
    dq 0
    dq 0

module_request:
    dq 0xc7b1dd30df4c8b88
    dq 0x0a82e883a194f07b
    dq 0x3e7e279702be32af
    dq 0xca1c4f3bd1280cee
    dq 0
    dq 0

section .bss
sector_buffer: resb 2048

section .text
global _start

_start:

   ; Valider la présence de l'écran
    mov rax, [framebuffer_request + 40]
    test rax, rax
    jz .halt

    call init_video
    call get_audio_device

    call init_idt
    sti

	; Détecter le CD Rom
	call detect_cdrom
    test rax, rax
    jz .halt

	; Lire le secteur 16
	mov rdi, 16
	lea rsi, [rel sector_buffer]
	call read_cdrom_sector
	test rax, rax
	jz .halt

	; Vérifier lire "CD001"
	lea rsi, [rel sector_buffer]
	mov al, byte [rsi + 1]
	cmp al, 'C'
	jne .halt
	
	mov al, byte [rsi + 2]
	cmp al, 'D'
	jne .halt

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
