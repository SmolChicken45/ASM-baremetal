[BITS 64]
DEFAULT REL

global system_ticks
global timer_handler

section .bss
align 8
system_ticks: resq 1    ; Notre chronomètre (64 bits

section .text

timer_handler:
    push rax

    inc qword [rel system_ticks]

    mov al, 0x20
    out 0x20, al

    pop rax
    iretq