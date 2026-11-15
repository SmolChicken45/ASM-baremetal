[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/memory.inc"
%include "platform/xhci.inc"

; =============================================================
; EXPORTATIONS
; =============================================================
global xhci_configure_ep1_in
global xhci_submit_mouse_read
global mouse_data_buffer


; =============================================================
; IMPORTATIONS
; =============================================================
extern hcd_tr_init                  ; hcd/ring.asm
extern hcd_tr_enqueue               ; hcd/ring.asm
extern hcd_cmd_configure_endpoint   ; hcd/cmd.asm
extern doorbell_base                ; hcd/init.asm

extern core_usb_input_context       ; core/usb_device.asm
extern current_slot_id              ; core/usb_event.asm

section .bss
align 4096
xhci_ep1_in_ring:       resb 4096

align 8
ep1_in_mgr:             resb tr_manager_t_size
mouse_data_buffer:      resb 8

section .text

; =============================================================
; xhci_configure_ep1_in : Prépare l'Input Context pour activer l'EP Interrupt IN
; =============================================================
xhci_configure_ep1_in:
    ; Initialiser le Transfer Ring de l'EP1 IN
    lea rdi, [rel ep1_in_mgr]
    lea rsi, [rel xhci_ep1_in_ring]
    mov rdx, 256
    call hcd_tr_init

    ; Préparer le Input Context
;    lea rsi, [rel xhci_output_context]
;    lea rdi, [rel xhci_input_context]
;    add rdi, 0x20
;    mov rcx, 16
;.copy_context:
;    mov eax, dword [rsi]
;    mov dword [rdi], eax
;    add rsi, 4
;    add rdi, 4
;    loop .copy_context

    lea rbx, [rel core_usb_input_context]

    ; Drop Context Flags = 0
    mov dword [rbx + 0x00], 0
    ; Add Context Flags = Bit 0 (Slot) | Bit 3 (EP1 IN)
    mov dword [rbx + 0x04], (1 << 0) | (1 << 3)

    ;Slot Context
    ; Le matériel exige que "Context Entries" idique le DCI le plus élevé actif
    ; On doit remplacer l'ancien '1' par '3' (Bits 27-31)
    mov eax, dword [rbx + 0x20]
    and eax, 0x07FFFFFF ; Effacer les anciens Context Entries
    or eax, (3 << 27)   ; Insérer 3
    mov dword [rbx + 0x20], eax

    ; EP1 IN Context (Offset 0x80)
    ; DWORD 1  : Error COutn (3), EP Type (7 = Interrupt IN), Max Packet (8)
    mov eax, (3 << 1) | (7 << 3) | (8 << 16)
    mov dword [rbx + 0x84], eax

    ; DWORD 2 & 3: TRDP (Pointeur Physique du Transfer RIng)
    mov rax, [rel ep1_in_mgr + tr_manager_t.base_phys]
    or rax, 1   ; Activer le bit DCS
    mov dword [rbx + 0x88], eax
    shr rax, 32
    mov dword [rbx + 0x8C], eax

    ; DWORD 4 : Average TRB Length (8) et Max ESIT Payload (8)
    ; Requis par le xHCI pour les Endpoints de type Interrupt
    mov eax, 8 | (8 << 16)
    mov dword [rbx + 0x90], eax

    ; Envoyer la commande au contrôleur
    call hcd_cmd_configure_endpoint
    ret

; =============================================================
; xhci_submit_mouse_read
; Ajoute un TRB de lecture sur l'anneau de l'EP1 IN
; =============================================================
xhci_submit_mouse_read:
    lea rdi, [rel ep1_in_mgr]

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
    mov ecx, dword [rel current_slot_id]
    mov dword [rdx + rcx * 4], 3

    PRINT_INLINE "[USB HID] Demande de lecture envoyée à la souris !"
    ret