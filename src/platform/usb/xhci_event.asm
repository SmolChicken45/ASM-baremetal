[BITS 64]
DEFAULT REL

%include "platform/serial.inc"

global xhci_poll_event

extern xhci_event_ring
extern xhci_event_ring_phys
extern xhci_runtime_base

section .rodata
    msg_new_event:          db "[xHCI] Nouvel evenement detecte !", 13, 10
    msg_new_event_len       equ $ - msg_new_event

section .data

    event_ccs:              db 1

section .bss
    event_ring_index:       resq 1

section .text

xhci_poll_event:
    push rbx
    push r12
    push r13

    ; TRB actuel
    lea rbx, [rel xhci_event_ring]
    mov r12, qword [rel event_ring_index]
    add rbx, r12

    mov eax, dword [rbx + 12]

    ; Vérifier le Cycle Bit (bit 0)
    mov cl, byte [rel event_ccs]
    mov edx, eax
    and edx, 1
    cmp dl, cl
    jne .no_event

    PRINT_SERIAL msg_new_event, msg_new_event_len

    add r12, 16
    cmp r12, 4096
    jl .update_erdp

    xor r12, r12
    xor byte [rel event_ccs], 1

.update_erdp:
    mov qword [rel event_ring_index], r12

    mov r13, qword [rel xhci_runtime_base]
    mov rax, qword [rel xhci_event_ring_phys]
    add rax, r12

    or rax, 8

    mov qword [r13 + 0x18], rax

.no_event:
    pop r13
    pop r12
    pop rbx
    ret