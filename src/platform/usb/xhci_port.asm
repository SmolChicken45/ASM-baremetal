[BITS 64]
DEFAULT REL

%include "platform/serial.inc"

global xhci_handle_port_change
extern xhci_op_base

; Pour trouver le registre PORTSC = Op_base + 0x400 + (16 * (Port_ID - 1))

section .rodata
    msg_plug:        db "[xHCI] PORT : Périphérique CONNECTÉ !", 13, 10
    msg_plug_len     equ $ - msg_plug

    msg_unplug:        db "[xHCI] PORT : Périphérique DÉCONNECTÉ !", 13, 10
    msg_unplug_len     equ $ - msg_unplug

section .text

; xchi_handle_port_change : Analyse l'état d'un port USB
; Entrée : RAX = Port ID

xhci_handle_port_change:
    push rbx
    push rcx
    push rdx

    mov rbx, qword [rel xhci_op_base]
    add rbx, 0x400

    dec rax         ; Port 1 = Index 0
    shl rax, 4
    add rbx, rax    ; RBX = PORTSC (32bits)

    mov ecx, dword [rbx]

    test ecx, 1     ; bit 0 = 1, appareil présent
    jz .device_unplugged

.device_plugged:
    PRINT_SERIAL msg_plug, msg_plug_len

    ; Reset électrique au port

    jmp .clear_status

.device_unplugged:
    PRINT_SERIAL msg_unplug, msg_unplug_len

    ; Détruire les structures mémoire de la clé USB

.clear_status:
    ; Acquitter le changement d'état (Write-1-to-Clear)
    ; bit 17

    mov ecx, dword [rbx]
    and ecx, 0xFF01FFFF     ; Masquer les autres W1C
    or ecx, (1 << 17)       ; Mettre le bit 17 (CSC) à 1
    mov dword [rbx], ecx

    pop rdx
    pop rcx
    pop rbx

    ret
