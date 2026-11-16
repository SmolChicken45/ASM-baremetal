[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/memory.inc"
%include "platform/xhci.inc"

; =============================================================
; EXPORTATIONS
; =============================================================
global xhci_submit_mouse_read
global mouse_data_buffer


; =============================================================
; IMPORTATIONS
; =============================================================
extern hcd_tr_enqueue               ; hcd/ring.asm
extern doorbell_base                ; hcd/init.asm

section .bss
align 4
mouse_data_buffer:      resb 8

section .text

; =============================================================
; xhci_submit_mouse_read
; Ajoute un TRB de lecture sur l'anneau de l'EP1 IN
; Entrée : RDI = usb_device_t*
; =============================================================
xhci_submit_mouse_read:
    push r12
    mov r12, rdi

    mov r8, qword [r12 + usb_device_t.endpoints + 3 * 8]
    test r8, r8
    jz .no_endpoint


    lea rdi, [r8 + usb_endpoint_t.tr_mgr]

    ; DWORD 0 & 1 Adresse physique du buffer
    lea rax, [rel mouse_data_buffer]
    VIRT_TO_PHYS rax

    ; DWORD 2 : Longueur du transfert (8 octets)
    mov r8d, 8

    ; DWORD 3 : TRB Type = 1 | IOC
    mov r9d, (1 << 10) | (1 << 5)

    call hcd_tr_enqueue

    ; Sonner le doorbell
    mov rdx, qword [rel doorbell_base]
    mov ecx, dword [r12 + usb_device_t.slot_id]
    mov dword [rdx + rcx * 4], 3

    PRINT_INLINE "[USB HID] Demande de lecture envoyée à la souris !"

.no_endpoint:
    pop r12
    ret