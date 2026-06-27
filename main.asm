[BITS 64]
DEFAULT REL

section .limine_reqs progbits alloc noexec write
align 8
    dq framebuffer_request
    dq 0

section .data
align 8
framebuffer_request:
    dq 0xc7b1dd30df4c8b88
    dq 0x0a82e883a194f07b
    dq 0x9d5827dcd881dd1f
    dq 0xafb1aa5a1b8eea61
    dq 0
    dq 0

section .text
global _start

_start:

    mov rax, [framebuffer_request + 40]
    test rax, rax
    jz .halt

    mov rcx, [rax + 16]
    mov rbx, [rcx]

    mov rdi, [rbx + 0]
    mov r12, [rbx + 8]
    mov r13, [rbx + 16]
    mov r14, [rbx + 24]

    mov rcx, 100000
    mov eax, 0xFFFFFF

.paint_loop:
    mov dword [rdi], eax
    add rdi, 4
    dec rcx
    jnz .paint_loop

.game_loop:
    jmp .game_loop


.halt:
    hlt
    jmp .halt
