[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/memory.inc"
%include "platform/xhci.inc"

; ===========================================================================
; EXPORTATIONS
; ===========================================================================
global core_usb_setup_device_context
global core_usb_output_context
global core_usb_input_context
global core_usb_dcbaa
global core_usb_ep0_mgr

; ===========================================================================
; IMPORTATIONS
; ===========================================================================
extern hcd_tr_init                      ; Depuis hcd/ring.asm

extern current_port_id                  ; core/usb_hub.asm
extern current_port_speed               ; core/usb_hub.asm


section .bss
align 4096
core_usb_input_context:     resb 4096   ; 1 page pour l'input context
core_usb_output_context:    resb 4096
core_usb_ep0_ring:          resb 4096   ; 1 page pour le Transfer Ring de l'EP0

align 64
core_usb_dcbaa:             resq 256    ; Tableau DCBAA

align 8
core_usb_ep0_mgr:           resb tr_manager_t_size

section .text

; ===========================================================================
; core_usb_setup_device_context : Prépare l'Input Context en RAM avec les paramètres du port
; et configure le Transfer Ring de l'Endpoint 0
; ===========================================================================
core_usb_setup_device_context:
    push rbx
    push rcx
    push rdx
    push r8

    ; Initialiser le gestionnaire du TR EP0
    lea rdi, [rel core_usb_ep0_mgr]
    lea rsi, [rel core_usb_ep0_ring]
    mov rdx, 256            ; Capacité (4096 Bytes / 16 = 256 TRBs)
    call hcd_tr_init

    ; Nettoyer la page de L'Input Context
    lea rdi, [rel core_usb_input_context]
    xor eax, eax
    mov rcx, 1024
    rep stosd

    ; RDI pointe à la fin de la page
    lea rbx, [rel core_usb_input_context]

    ; Add Context Flags (Offset 0x04)
    mov dword [rbx + CTX_ADD_FLAGS], (ICS_ADD_SLOT | ICS_ADD_EP0)

    ; ===========================================================================
    ; CONFIGURATION DU SLOT CONTEXT (Offset 0x20)
    ; ===========================================================================
    ; Décrit le périphérique de façon globale

    ; dword 0 (Offset 0x20) : Route String (0), Speed, Multi-TT (0), Context Entries
    mov eax, dword [rel current_port_speed]
    shl eax, SLOT_SPEED_SHIFT         ; La vitesse est aux bits 20-23
    or eax, (1 << SLOT_ENTRIES_SHIFT)   ; Context Entries (BIts 27-31) = 1 (seul EP0 est actif)
    mov dword [rbx + CTX_SLOT], eax

    ; dword 1 (Offset 0x24) : Max Exit Latency (0), Root Hub Port Number
    mov eax, dword [rel current_port_id]
    shl eax, SLOT_PORT_SHIFT             ; Le numéro du port racine est aux bits 16-23
    mov dword [rbx + CTX_SLOT_DWORD1], eax

    ; ===========================================================================
    ; CONFIGURATION DU EP0 CONTEXT (Offset 0x40)
    ; ===========================================================================

    ; Dword 1 (Offset 0x44) : Error Count (3), EP Type (4), Max Packet Size
    ; le type pour EP0 est toujours 4 (Control Bidirectionnel)
    ; la taille du paquet dépend de la vitesse. Pour FS = 8, HS = 64, SS = 512
    ; Souvent les vieux périphériques FS disent 8 par défaut
    ; SI HS c'est 64

    mov ecx, dword [rel current_port_speed]
    cmp ecx, 3
    je .set_hs_packet

    cmp ecx, 4
    je .set_ss_packet

.set_fs_packet:
    mov edx, 8
    jmp .write_ep0

.set_hs_packet:
    mov edx, 64
    jmp .write_ep0

.set_ss_packet:
    mov edx, 512

.write_ep0:
    ; Construire le DWORD : Error Count (bit 1-2) = 3, EP Type (bit 3-5) = 4, MAx Packet Size (16-31)
    mov eax, (EP_ERR_COUNT_3 << EP_ERR_COUNT_SHIFT) | (EP_TYPE_CONTROL << EP_TYPE_SHIFT)
    shl edx, 16
    add eax, edx
    mov dword [rbx + CTX_EP0_DWORD1], eax

    ; Dword 2 et 3 (Offset 0x48 et 0x4C) : TR Dequeue Pointer (Adresse Physique du Transfer Ring)
    ; On doit donner xHCI l'adresse Physique du Transfer RIng qu'on a alloué
    mov rax, [rel core_usb_ep0_mgr + tr_manager_t.base_phys]
    or rax, 1       ; Activer le bit 0 (DCX - Dequeue Cycle State)

    mov dword [rbx + CTX_EP0_TRDP_LO], eax
    shr rax, 32
    mov dword [rbx + CTX_EP0_TRDP_HI], eax

    PRINT_INLINE "[USB Core] Context Input, Slot et EP0 configurés en RAM."

    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret