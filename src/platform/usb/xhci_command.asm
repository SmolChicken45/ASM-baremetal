[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/memory.inc"
%include "platform/xhci.inc"

global xhci_send_enable_slot_cmd
global xhci_send_address_device_cmd
global device_init_state

extern xhci_cmd_ring        ; Tableau de 4096 octets
extern command_ring_index   ; 0 - 255
extern command_cycle_state  ; 0 - 1
extern xhci_doorbell_base   ; Pointeur pour avertir une commande
extern xhci_input_context
extern current_slot_id

extern xhci_op_base

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
    mov dword [rbx + TRB_DWORD0], 0
    mov dword [rbx + TRB_DWORD1], 0
    mov dword [rbx + TRB_DWORD2], 0

    ; DWORD 3  TRB Type (bit 10-15) et Cycle Bit (bit 0)
    mov eax, (TRB_TYPE_ENABLE_SLOT << TRB_TYPE_SHIFT)

    xor edx, edx
    mov dl, byte [rel command_cycle_state]
    and dl, 1
    or eax, edx


    mov dword [rbx + TRB_DWORD3], eax

    mov rcx, qword [rel command_ring_index]
    inc rcx

    ; TODO Ajouter le wrap around

    mov qword [rel command_ring_index], rcx

    mov dword [rel device_init_state], DEV_STATE_WAIT_SLOT
    mov rdx, qword [rel xhci_doorbell_base]
    mov dword [rdx + 0x00], 0

    PRINT_INLINE "[xHCI] Commande ENABLE SLOT envoyée. En attente de l'Event..."

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
    VIRT_TO_PHYS rax

    ; Trouver le prochain TRB dans le Command Ring
    lea rbx, [rel xhci_cmd_ring]
    mov rcx, qword [rel command_ring_index]
    shl rcx, 4
    add rbx, rcx

    ; Écrire le TRB Address Device (Type 11)
    ; Dword 0 er 1 : Adresse physique de l'Input Context
    mov dword [rbx + TRB_DWORD0], eax
    shr rax, 32
    mov dword [rbx + TRB_DWORD1], eax

    ; dword 2 : Réservé (0)
    mov dword [rbx + TRB_DWORD2], 0

    ; dword 3 : Cycle Bit (0), TRB Type (11), Slot ID (24-31)
    mov eax, (TRB_TYPE_ADDRESS_DEV << TRB_TYPE_SHIFT)

    mov ecx, dword [rel current_slot_id]
    shl ecx, TRB_SLOT_ID_SHIFT
    or eax, ecx

    ; Ajouter le bit de cycle
    xor edx, edx
    mov dl, byte [rel command_cycle_state]
    and dl, 1
    or eax, edx

    mov dword [rbx + TRB_DWORD3], eax

    ; Avancer l'index et sonner la Doorbell 0
    mov rcx, qword [rel command_ring_index]
    inc rcx
    cmp rcx, 255
    jne .save_addr_index

    xor rcx, rcx
    xor byte [rel command_cycle_state], 1

.save_addr_index:
    mov qword [rel command_ring_index], rcx

    mov dword [rel device_init_state], DEV_STATE_WAIT_ADDR
    mov rdx, qword [rel xhci_doorbell_base]
    mov dword [rdx + 0x00], 0

    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret