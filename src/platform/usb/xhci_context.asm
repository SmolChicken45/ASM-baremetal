[BITS 64]
DEFAULT REL

%include "platform/serial.inc"

global xhci_setup_device_context

extern current_port_id
extern current_port_speed
extern get_kernel_address_response

section .bss
align 4096
xhci_input_context: resb 4096   ; 1 page pour l'input context
xhci_ep0_ring:      resb 4096   ; 1 page pour le Transfer Ring de l'EP0

section .rodata
    msg_ctx_ok:         db "[xHCI] Context Input, Slot et EP0 configurés en RAM.", 13, 10
    msg_ctx_ok_len      equ $ - msg_ctx_ok

section .text

; xhci_setup_device_context : Remplit es structures de données (contextes)
; Nécessaires pour la commande Address Device

xhci_setup_device_context:
    push rbx
    push rcx
    push rdx
    push r8

    ; Nettoyer la page de L'Input COntext
    lea rdi, [rel xhci_input_context]
    xor eax, eax
    mov rcx, 1024
    rep stosd

    ; RDI pointe à la fin de la page
    lea rbx, [rel xhci_input_context]

    ; Offset 0x00 = Input Control Context
    ; Il dit quel sont les contextes valides dans ce bloc
    ; on doit ajouter les contextes Slot Context (bit 0) et EP0 (bit 1)

    ; Add Context Flags (Offset 0x04)
    mov dword [rbx + 0x04], 0x03

    ; Offset 0x20 = Slot Context
    ; Décrit le périphérique de façon globale

    ; dword 0 (Offset 0x20) : Route String (0), Speed, Multi-TT (0), Context Entries
    mov eax, dword [rel current_port_speed]
    shl eax, 20         ; La vitesse est aux bits 20-23
    or eax, (1 << 27)   ; Context Entries (BIts 27-31) = 1 (seul EP0 est actif)
    mov dword [rbx + 0x20], eax

    ; dword 1 (Offset 0x24) : Max Exit Latency (0), Root Hub Port Number
    mov eax, dword [rel current_port_id]
    shl eax, 16             ; Le numéro du port racine est aux bits 16-23
    mov dword [rbx + 0x24], eax

    ; Offset 0x40 = Endpoint 0 Context (EP0)

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
    mov eax, (3 << 1) | (4 << 3)
    shl edx, 16
    add eax, edx
    mov dword [rbx + 0x44], eax

    ; Dword 2 et 3 (Offset 0x48 et 0x4C) : TR Dequeue Pointer (Adresse Physique du Transfer Ring)
    ; On doit donner xHCI l'adresse Physique du Transfer RIng qu'on a alloué
    lea rax, [rel xhci_ep0_ring]
    mov rdi, [rel get_kernel_address_response]

    mov rcx, qword [rdi + 0x10]
    sub rax, rcx
    mov rdx, qword [rdi + 0x08]
    add rax, rdx

    or rax, 1       ; Activer le bit 0 (DCX - Dequeue Cycle State)
    mov dword [rbx + 0x48], eax
    shr rax, 32
    mov dword [rbx + 0x4C], eax

    PRINT_SERIAL msg_ctx_ok, msg_ctx_ok_len

    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret