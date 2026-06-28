[BITS 64]
DEFAULT REL

extern get_audio_device
extern init_video


section .limine_reqs progbits alloc noexec write
align 8
    dq framebuffer_request
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

section .text
global _start

_start:

    mov rax, [framebuffer_request + 40]
    test rax, rax
    jz .halt

    call init_video
    call get_audio_device


.game_loop:
    jmp .game_loop


.halt:
    hlt
    jmp .halt
