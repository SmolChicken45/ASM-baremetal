[BITS 64]
DEFAULT REL

%include "platform/serial.inc"

global xhci_send_enable_slot_cmd

extern xhci_cmd_ring        ; Tableau de 4096 octets
extern command_ring_index   ; 0 - 255
extern command_cycle_state  ; 0 - 1
extern xhci_doorbell_base   ; Pointeur pour avertir une commande

section .rodata
    msg_cmd_sent:       db "[xHCI] Commande ENABLE SLOT envoyée. En attente de l'Event...", 13, 10
    msg_cmd_sent_len    equ $ - msg_cmd_sent

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

    mov rdx, qword [rel xhci_doorbell_base]
    mov dword [rdx + 0x00], 0

    PRINT_SERIAL msg_cmd_sent, msg_cmd_sent_len

    pop rdx
    pop rcx
    pop rbx
    ret