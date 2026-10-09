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

    msg_reset_ok:      db "[xHCI] PORT : Reset termine, port actif et prêt !", 13, 10
    msg_reset_ok_len   equ $ - msg_reset_ok

    msg_speed:         db "[xHCI] Vitesse du port (1=FS, 2=LS, 3=HS, 4=SS) : "
    msg_speed_len      equ $ - msg_speed
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
    test ecx, (1 << 17)
    jz .clear_leftover_changes

    test ecx, 1     ; bit 0 = 1, appareil présent
    jz .device_unplugged

.device_plugged:
    PRINT_SERIAL msg_plug, msg_plug_len

    ; Reset électrique au port
    mov ecx, dword [rbx]
    and ecx, 0xFF01FFFF

    or ecx, (1 << 4)
    mov dword [rbx], ecx

.wait_reset:
    ; Attendre que le bit 21 (PRC) passe à 1
    pause
    mov ecx, dword [rbx]
    test ecx, (1 << 21)
    jz .wait_reset

    PRINT_SERIAL msg_reset_ok, msg_reset_ok_len

    ; Acquitter le Port Reset Change (PRC)
    mov ecx, dword [rbx]
    and ecx, 0xFF01FFFF
    or ecx, (1 << 17) | (1 << 19) | (1 << 21)
    mov dword [rbx], ecx

    ; Lecture de la vitesse du périphérique
    mov eax, dword [rbx]

    shr eax, 10     ; Amener le bit 10 à la pos 0
    and eax, 0x0F   ; Masquer pour garder 4 bits

    PRINT_SERIAL msg_speed, msg_speed_len
    PRINT_SERIAL_HEX rax

    jmp .done

.device_unplugged:
    PRINT_SERIAL msg_unplug, msg_unplug_len

    ; Détruire les structures mémoire de la clé USB
    ; Acquitter seulement CSC
    mov ecx, dword [rbx]
    and ecx, 0xFF01FFFF
    or ecx, (1 << 17)
    mov dword [rbx], ecx
    jmp .done

.clear_leftover_changes:


    mov ecx, dword [rbx]
    and ecx, 0xFFFFFFEF     ; Tout acquitter puis forcer bit 4 à 0
    mov dword [rbx], ecx

.done:
    pop rdx
    pop rcx
    pop rbx

    ret
