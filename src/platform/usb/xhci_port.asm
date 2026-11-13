[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/xhci.inc"

global xhci_handle_port_change
global current_port_id
global current_port_speed

extern xhci_op_base
extern xhci_send_enable_slot_cmd

section .bss
current_port_id: resd 1
current_port_speed: resd 1

section .text

; xchi_handle_port_change : Analyse l'état d'un port USB
; Entrée : RAX = Port ID

xhci_handle_port_change:
    push rbx
    push rcx
    push rdx

    mov rbx, qword [rel xhci_op_base]
    add rbx, XHCI_PORTSC_BASE

    dec rax         ; Port 1 = Index 0
    shl rax, 4      ; *16 (taille d'un registre PORTSC
    add rbx, rax    ; RBX = PORTSC (32bits)

    ; Vérifier s'il y a un changement de statut de connexion (CSC)
    mov ecx, dword [rbx]
    test ecx, XHCI_PORTSC_CSC
    jz .clear_leftover_changes

    ; Vérifier si le périphérique est présent (CCS)
    test ecx, XHCI_PORTSC_CCS     ; bit 0 = 1, appareil présent
    jz .device_unplugged

.device_plugged:
    PRINT_INLINE "[xHCI] PORT : Périphérique CONNECTÉ !"

    ; Reset électrique au port (PR)
    mov ecx, dword [rbx]
    and ecx, XHCI_PORTSC_MASK
    or ecx, XHCI_PORTSC_PR
    mov dword [rbx], ecx

.wait_reset:
    ; Attendre que le bit 21 (PRC) passe à 1
    pause
    mov ecx, dword [rbx]
    test ecx, XHCI_PORTSC_PRC
    jz .wait_reset

    PRINT_INLINE "[xHCI] PORT : Reset termine, port actif et prêt !"

    ; Acquitter le Port Reset Change (PRC)
    mov ecx, dword [rbx]
    and ecx, XHCI_PORTSC_MASK
    or ecx, (XHCI_PORTSC_CSC | XHCI_PORTSC_PLC | XHCI_PORTSC_PRC)
    mov dword [rbx], ecx

    ; Sauvegarder l'ID du port (remettre en 1-based)
    shr rax, 4
    inc rax
    mov dword [rel current_port_id], eax

    ; Lecture de la vitesse du périphérique
    mov eax, dword [rbx]
    shr eax, XHCI_PORTSC_SPEED_SHIFT     ; Amener le bit 10 à la pos 0
    and eax, XHCI_PORTSC_SPEED_MASK   ; Masquer pour garder 4 bits

    mov dword [rel current_port_speed], eax
    LOG_HEX "[xHCI] Vitesse du port (1=FS, 2=LS, 3=HS, 4=SS) : ", rax

    ; Demander un Slot ID pour le nouveau périphérique
    call xhci_send_enable_slot_cmd

    jmp .done

.device_unplugged:
    PRINT_INLINE "[xHCI] PORT : Périphérique DÉCONNECTÉ !"

    ; TODO Détruire les structures mémoire de la clé USB
    ; Acquitter seulement CSC
    mov ecx, dword [rbx]
    and ecx, XHCI_PORTSC_MASK
    or ecx, XHCI_PORTSC_CSC
    mov dword [rbx], ecx
    jmp .done

.clear_leftover_changes:

    ; Tout acquitter puis forcer bit 4 à 0
    mov ecx, dword [rbx]
    and ecx, XHCI_PORTSC_CLEAR_ALL
    mov dword [rbx], ecx

.done:
    pop rdx
    pop rcx
    pop rbx

    ret
