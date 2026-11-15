[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/memory.inc"
%include "platform/xhci.inc"

; =======================================================================
; EXPORTATIONS
; =======================================================================
global hcd_cmd_enable_slot
global hcd_cmd_disable_slot
global hcd_cmd_address_device
global hcd_cmd_configure_endpoint


; =======================================================================
; IMPORTATIONS
; =======================================================================
extern doorbell_base   ; Pointeur pour avertir une commande
extern cmd_ring_mgr
extern hcd_tr_enqueue

; Ces variables appartiennet à la couche Core
extern core_usb_input_context
extern current_slot_id


extern xhci_op_base

section .text

; =======================================================================
; hcd_cmd_enable_slot ; Demande un nouvea Slot ID au xHCI
; =======================================================================
hcd_cmd_enable_slot:
    push rdi

    lea rdi, [rel cmd_ring_mgr]
    xor rax, rax        ; Parameter = 0
    xor r8d, r8d        ; Status = 0
    mov r9d, (TRB_TYPE_ENABLE_SLOT << TRB_TYPE_SHIFT) ; Control (sans bit 0)

    call hcd_tr_enqueue

    ; Mettre à jour l'état et sonner la Doorbell 0
    mov rdx, qword [rel doorbell_base]
    mov dword [rdx + 0x00], 0

    pop rdi
    ret

; =======================================================================
; hcd_cmd_disable_slot ; Désactive un Slot au niveau matériel
; =======================================================================
hcd_cmd_disable_slot:
    push rdi

    lea rdi, [rel cmd_ring_mgr]
    xor rax, rax        ; Parameter = 0
    xor r8d, r8d        ; Status = 0
    ; TRB Type 10 (Disable Slot) | Slot ID
    mov r9d, dword [rel current_slot_id]
    shl r9d, 24
    or r9d, (10 << 10)

    call hcd_tr_enqueue

    ; Sonner le Doorbell
    mov rdx, qword [rel doorbell_base]
    mov dword [rdx], 0

    pop rdi
    ret

; =======================================================================
; hcd_cmd_address_device : Assigne une adresse USB au périphérique et configure l'EP0
; =======================================================================
hcd_cmd_address_device:

    push rdi
    ; Obtenir l'adresse de Input Context en Physique
    lea rax, [rel core_usb_input_context]
    VIRT_TO_PHYS rax        ; RAX = Parameter

    ; Préparer Status et Control
    xor r8d, r8d


    ; dword 3 : Cycle Bit (0), TRB Type (11), Slot ID (24-31)
    mov r9d, (TRB_TYPE_ADDRESS_DEV << TRB_TYPE_SHIFT)

    mov ecx, dword [rel current_slot_id]
    shl ecx, TRB_SLOT_ID_SHIFT
    or r9d, ecx             ; Control = Type 11 | Slot ID

    ; Insérer le TRB dans le Command Ring
    lea rdi, [rel cmd_ring_mgr]
    call hcd_tr_enqueue

    ; Mettre à jour l'état et sonner la Doorbell 0
    mov rdx, qword [rel doorbell_base]
    mov dword [rdx + 0x00], 0

    pop rdi
    ret

; =======================================================================
; hcd_cmd_configure_endpoint
; Demande au contrôleur d'activer les Endpoints listés dans l'Input Context
; =======================================================================
hcd_cmd_configure_endpoint:

    lea rdi, [rel cmd_ring_mgr]
    ; Pointeur physique vers l'Input Context
    lea rax, [rel core_usb_input_context]
    VIRT_TO_PHYS rax

    xor r8d, r8d

    ; TRB de Commande Type 12 (Configure Endpoint)
    ; DWORD 0 & 1 : adresse physique (rax)
    ; DWORD 3 : Slot ID (bits 24-31) | Type (bits 10-15)
    mov r9d, dword [rel current_slot_id]
    shl r9d, 24
    or r9d, (12 << 10)      ; TRB Type 12

    call hcd_tr_enqueue

    ; Sonner le Doorbell du Host Controller
    mov rdx, qword [rel doorbell_base]
    mov dword [rdx], 0

    ret