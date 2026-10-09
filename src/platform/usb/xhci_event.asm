[BITS 64]
DEFAULT REL

%include "platform/serial.inc"

global xhci_poll_event

extern xhci_event_ring
extern xhci_event_ring_phys
extern xhci_runtime_base
extern xhci_handle_port_change

section .rodata
    msg_new_event:          db "[xHCI] Nouvel evenement detecte !", 13, 10
    msg_new_event_len       equ $ - msg_new_event

    msg_port_change:        db "[xHCI] HOTPLUG : Port Status Change Event recu !", 13, 10
    msg_port_change_len     equ $ - msg_port_change

    msg_port_id:            db "[xHCI] -> Sur le Port ID : ", 0
    msg_port_id_len         equ $ - msg_port_id

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

    mov edx, eax
    shr edx, 10
    and edx, 0x3F

    cmp edx, 34
    je .is_port_change

    PRINT_SERIAL msg_new_event, msg_new_event_len
    jmp .continue_event

.is_port_change:

    ; PRINT_SERIAL msg_port_change, msg_port_change_len
    ; PRINT_SERIAL msg_port_id, msg_port_id_len

    mov eax, dword [rbx + 0]
    shr eax, 24

    call xhci_handle_port_change

    jmp .continue_event

.continue_event:

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