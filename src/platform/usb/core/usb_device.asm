[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/memory.inc"
%include "platform/xhci.inc"

; ===========================================================================
; EXPORTATIONS
; ===========================================================================
global core_usb_setup_device_context
global core_usb_dcbaa


section .bss
align 64
core_usb_dcbaa:             resq 256    ; Tableau DCBAA

section .text

; ===========================================================================
; core_usb_setup_device_context : Prépare l'Input Context en RAM avec les paramètres du port
; et configure le Transfer Ring de l'Endpoint 0
; ===========================================================================
core_usb_setup_device_context:
    mov r11, rdi

    ; Nettoyer la page de L'Input Context
    mov rdi, [r11 + usb_device_t.input_ctx_virt]
    mov r9, rdi
    xor eax, eax
    mov rcx, 1024
    rep stosd
    ; Inscription au DCBAA
    movzx ecx, byte [r11 + usb_device_t.slot_id]
    mov rax, qword [r11 + usb_device_t.output_ctx_phys]

    lea r8, qword [rel core_usb_dcbaa]
    mov qword [r8 + rcx * 8], rax

    ; Add Context Flags (Offset 0x04)
    mov dword [r9 + CTX_ADD_FLAGS], (ICS_ADD_SLOT | ICS_ADD_EP0)

    ; ===========================================================================
    ; CONFIGURATION DU SLOT CONTEXT (Offset 0x20)
    ; ===========================================================================
    ; Décrit le périphérique de façon globale

    ; dword 0 (Offset 0x20) : Route String (0), Speed, Multi-TT (0), Context Entries
    movzx eax, byte [r11 + usb_device_t.speed]
    shl eax, SLOT_SPEED_SHIFT         ; La vitesse est aux bits 20-23
    or eax, (1 << SLOT_ENTRIES_SHIFT)   ; Context Entries (BIts 27-31) = 1 (seul EP0 est actif)
    mov dword [r9 + CTX_SLOT], eax

    ; dword 1 (Offset 0x24) : Max Exit Latency (0), Root Hub Port Number
    movzx eax, byte [r11 + usb_device_t.port_id]
    shl eax, SLOT_PORT_SHIFT             ; Le numéro du port racine est aux bits 16-23
    mov dword [r9 + CTX_SLOT_DWORD1], eax

    ; ===========================================================================
    ; CONFIGURATION DU EP0 CONTEXT (Offset 0x40)
    ; ===========================================================================

    ; Dword 1 (Offset 0x44) : Error Count (3), EP Type (4), Max Packet Size
    ; le type pour EP0 est toujours 4 (Control Bidirectionnel)
    ; la taille du paquet dépend de la vitesse. Pour FS = 8, HS = 64, SS = 512
    ; Souvent les vieux périphériques FS disent 8 par défaut
    ; SI HS c'est 64

    mov ecx, dword [r11 + usb_device_t.speed]
    cmp ecx, XHCI_SPEED_HIGH
    je .set_hs_packet

    cmp ecx, XHCI_SPEED_SUPER
    je .set_ss_packet

.set_fs_packet:
    mov edx, USB_EP0_MAX_FS_LS
    jmp .write_ep0

.set_hs_packet:
    mov edx, USB_EP0_MAX_HS
    jmp .write_ep0

.set_ss_packet:
    mov edx, USB_EP0_MAX_SS

.write_ep0:
    ; Construire le DWORD : Error Count (bit 1-2) = 3, EP Type (bit 3-5) = 4, MAx Packet Size (16-31)
    mov eax, (EP_ERR_COUNT_3 << EP_ERR_COUNT_SHIFT) | (EP_TYPE_CONTROL << EP_TYPE_SHIFT)
    shl edx, 16
    or eax, edx
    mov dword [r9 + CTX_EP0_DWORD1], eax

    ; Dword 2 et 3 (Offset 0x48 et 0x4C) : TR Dequeue Pointer (Adresse Physique du Transfer Ring)
    ; On doit donner xHCI l'adresse Physique du Transfer RIng qu'on a alloué
    mov r8, qword [r11 + usb_device_t.endpoints + 1 * 8]
    mov rax, qword [r8 + usb_endpoint_t.tr_mgr + tr_manager_t.base_phys]
    or rax, CTX_EP_TRDP_DCS_BIT      ; Activer le bit 0 (DCX - Dequeue Cycle State)

    mov dword [r9 + CTX_EP0_TRDP_LO], eax
    shr rax, 32
    mov dword [r9 + CTX_EP0_TRDP_HI], eax

    PRINT_INLINE "[USB Core] Context Input, Slot et EP0 configurés en RAM."
    ret