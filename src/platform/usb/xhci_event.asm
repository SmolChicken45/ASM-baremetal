[BITS 64]
DEFAULT REL

%include "platform/serial.inc"

global xhci_poll_event
global current_slot_id

extern xhci_event_ring
extern xhci_event_ring_phys
extern xhci_runtime_base
extern xhci_handle_port_change
extern xhci_setup_device_context
extern xhci_output_context
extern get_kernel_address_response
extern xhci_dcbaa
extern xhci_send_address_device_cmd
extern device_init_state


section .rodata
    msg_new_event:          db "[xHCI] Nouvel evenement detecte !", 13, 10
    msg_new_event_len       equ $ - msg_new_event

    msg_port_change:        db "[xHCI] HOTPLUG : Port Status Change Event recu !", 13, 10
    msg_port_change_len     equ $ - msg_port_change

    msg_port_id:            db "[xHCI] -> Sur le Port ID : "
    msg_port_id_len         equ $ - msg_port_id

    msg_cmd_ok:             db "[xHCI] Commande terminée avec succès ! Slot ID obtenu : "
    msg_cmd_ok_len          equ $ - msg_cmd_ok

    msg_cmd_fail:           db "[xHCI] Commande terminée avec une faute", 13, 10
    msg_cmd_fail_len        equ $ - msg_cmd_fail

    msg_addr_ok:            db "[xHCI] Address device réussi !, Adresse USB : "
    msg_addr_ok_len         equ $ - msg_addr_ok

section .data

    event_ccs:              db 1

section .bss
    event_ring_index:       resq 1
    current_slot_id:        resd 1

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

    cmp edx, 33
    je .is_cmd_completion

    PRINT_SERIAL msg_new_event, msg_new_event_len
    jmp .continue_event

.is_port_change:

    ; PRINT_SERIAL msg_port_change, msg_port_change_len
    ; PRINT_SERIAL msg_port_id, msg_port_id_len

    mov eax, dword [rbx + 0]
    shr eax, 24

    call xhci_handle_port_change

    jmp .continue_event

.is_cmd_completion:

    mov ecx, dword [rbx + 8]
    shr ecx, 24
    cmp ecx, 1
    jne .cmd_failed

    mov eax, dword [rel device_init_state]
    cmp eax, 1
    je .handle_enable_slot_success

    cmp eax, 2
    je .handle_address_device_success

    jmp .continue_event

.handle_enable_slot_success:
    mov ecx, dword [rbx + 12]   ; Lire le dword 3
    shr ecx, 24                 ; Isoler le Slot ID (24-31)

    mov dword [rel current_slot_id], ecx

    PRINT_SERIAL msg_cmd_ok, msg_cmd_ok_len
    mov rax, rcx
    PRINT_SERIAL_HEX rax

    ; Création des context
    call xhci_setup_device_context

    ; output_context en adresse Physique
    lea rax, [rel xhci_output_context]
    mov rdi, [rel get_kernel_address_response]
    mov rcx, qword [rdi + 0x10]
    sub rax, rcx
    mov rdx, qword [rdi + 0x08]
    add rax, rdx

    lea rbx, qword [rel xhci_dcbaa]
    mov ecx, dword [rel current_slot_id]
    mov qword [rbx + rcx * 8], rax

    call xhci_send_address_device_cmd

    jmp .continue_event

.handle_address_device_success:
    PRINT_SERIAL msg_addr_ok, msg_addr_ok_len

    ; La commande a réussi, l'adresse USB a été attirbuée par le matéiel
    ; Le xHCI a écrit cette adresse dans le Slot Context de l'OUTPUT Context
    ; Le Slot COntext commence à l'offset 0x00 de l'Output COntext
    ; L'adresse USB est dans le DWORD 3
    lea rbx, [rel xhci_output_context]
    mov eax, dword [rbx + 0x0C]
    and eax, 0xFF

    PRINT_SERIAL_HEX rax

    mov dword [rel device_init_state], 0

    jmp .continue_event

.cmd_failed:
    PRINT_SERIAL msg_cmd_fail, msg_cmd_fail_len

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