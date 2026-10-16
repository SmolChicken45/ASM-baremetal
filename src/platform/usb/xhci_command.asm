[BITS 64]
DEFAULT REL

%include "platform/serial.inc"

global xhci_send_enable_slot_cmd
global xhci_send_address_device_cmd
global device_init_state

extern xhci_cmd_ring        ; Tableau de 4096 octets
extern command_ring_index   ; 0 - 255
extern command_cycle_state  ; 0 - 1
extern xhci_doorbell_base   ; Pointeur pour avertir une commande
extern get_kernel_address_response
extern xhci_input_context
extern current_slot_id

section .rodata
    msg_cmd_sent:       db "[xHCI] Commande ENABLE SLOT envoyée. En attente de l'Event...", 13, 10
    msg_cmd_sent_len    equ $ - msg_cmd_sent

section .bss

    device_init_state: resd 1

section .text

; xhci_send_enable_slot_cmd ; Demande un nouvea Slot ID au xHCI

xhci_send_enable_slot_cmd:
    push rbx
    push rcx
    push rdx

    ; Trouver le TRB actuel
    lea rbx, [rel xhci_cmd_ring]
    mov rcx, qword [rel command_ring_index]
    shl rcx, 4
    add rbx, rcx        ; RBX point sur le TRB à écrire

    ; Forger la commande (type = 9)
    mov dword [rbx + 0], 0
    mov dword [rbx + 4], 0
    mov dword [rbx + 8], 0

    ; DWORD 3  TRB Type (bit 10-15) et Cycle Bit (bit 0)
    mov eax, (9 << 10)

    xor edx, edx
    mov dl, byte [rel command_cycle_state]
    and dl, 1
    or eax, edx

    mov dword [rbx + 12], eax

    mov rcx, qword [rel command_ring_index]
    inc rcx

    ; TODO Ajouter le wrap around

    mov qword [rel command_ring_index], rcx

    mov dword [rel device_init_state], 1
    mov rdx, qword [rel xhci_doorbell_base]
    mov dword [rdx + 0x00], 0

    PRINT_SERIAL msg_cmd_sent, msg_cmd_sent_len

    pop rdx
    pop rcx
    pop rbx
    ret

xhci_send_address_device_cmd:
    push rbx
    push rcx
    push rdx
    push rdi

    ; Obtenir l'adresse de Input Context en Physique
    lea rax, [rel xhci_input_context]
    mov rdi, [rel get_kernel_address_response]
    mov rcx, qword [rdi + 0x10]
    sub rax, rcx
    mov rdx, qword [rdi + 0x08]
    add rax, rdx

    ; Trouver le prochain TRB dans le Command Ring
    lea rbx, [rel xhci_cmd_ring]
    mov rcx, qword [rel command_ring_index]
    shl rcx, 4
    add rbx, rcx

    ; Écrire le TRB Address Device (Type 11)
    ; Dword 0 er 1 : Adresse physique de l'Input Context
    mov dword [rbx + 0], eax
    shr rax, 32
    mov dword [rbx + 4], eax

    ; dword 2 : Réservé (0)
    mov dword [rbx + 8], 0

    ; dword 3 : Cycle Bit (0), TRB Type (11), Slot ID (24-31)
    mov eax, (11 << 10)

    mov ecx, dword [rel current_slot_id]
    shl ecx, 24
    or eax, ecx

    ; Ajouter le bit de cycle
    xor edx, edx
    mov dl, byte [rel command_cycle_state]
    and dl, 1
    or eax, edx

    mov dword [rbx + 12], eax

    ; Avancer l'index et sonner la Doorbell 0
    inc qword [rel command_ring_index]
    mov dword [rel device_init_state], 2
    mov rdx, qword [rel xhci_doorbell_base]
    mov dword [rdx + 0x00], 0

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret