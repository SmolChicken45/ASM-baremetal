[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/memory.inc"
%include "platform/xhci.inc"

global xhci_send_enable_slot_cmd
global xhci_send_address_device_cmd
global device_init_state

extern xhci_doorbell_base   ; Pointeur pour avertir une commande
extern xhci_input_context
extern current_slot_id
extern xhci_cmd_ring_mgr
extern tr_enqueue

extern xhci_op_base

section .bss

    device_init_state: resd 1

section .text

; xhci_send_enable_slot_cmd ; Demande un nouvea Slot ID au xHCI

xhci_send_enable_slot_cmd:
    push rdi

    lea rdi, [rel xhci_cmd_ring_mgr]
    xor rax, rax        ; Parameter = 0
    xor r8d, r8d        ; Status = 0
    mov r9d, (TRB_TYPE_ENABLE_SLOT << TRB_TYPE_SHIFT) ; Control (sans bit 0)

    call tr_enqueue

    ; Mettre à jour l'état et sonner la Doorbell 0
    mov dword [rel device_init_state], DEV_STATE_WAIT_SLOT
    mov rdx, qword [rel xhci_doorbell_base]
    mov dword [rdx + 0x00], 0

    PRINT_INLINE "[xHCI] Commande ENABLE SLOT envoyée. En attente de l'Event..."

    pop rdi
    ret

xhci_send_address_device_cmd:

    push rdi
    ; Obtenir l'adresse de Input Context en Physique
    lea rax, [rel xhci_input_context]
    VIRT_TO_PHYS rax        ; RAX = Parameter

    ; Préparer Status et Control
    xor r8d, r8d


    ; dword 3 : Cycle Bit (0), TRB Type (11), Slot ID (24-31)
    mov r9d, (TRB_TYPE_ADDRESS_DEV << TRB_TYPE_SHIFT)

    mov ecx, dword [rel current_slot_id]
    shl ecx, TRB_SLOT_ID_SHIFT
    or r9d, ecx             ; Control = Type 11 | Slot ID

    ; Insérer le TRB dans le Command Ring
    lea rdi, [rel xhci_cmd_ring_mgr]
    call tr_enqueue

    ; Mettre à jour l'état et sonner la Doorbell 0
    mov dword [rel device_init_state], DEV_STATE_WAIT_ADDR
    mov rdx, qword [rel xhci_doorbell_base]
    mov dword [rdx + 0x00], 0

    pop rdi
    ret