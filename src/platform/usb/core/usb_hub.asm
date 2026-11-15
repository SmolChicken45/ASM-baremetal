[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/xhci.inc"

; ================================================================
; EXPORTATIONS
; ================================================================
global core_usb_handle_port_change

; Variables globales partagé avec core/usb_device.asm
global current_port_id
global current_port_speed

; ================================================================
; EXPORTATIONS
; ================================================================
extern op_base                          ; hcd/init.asm
extern hcd_cmd_enable_slot              ; hcd/cmd.asm
extern hcd_cmd_disable_slot             ; hcd/cmd.asm
extern device_init_state                ; core/event.asm

section .bss
current_port_id:        resd 1
current_port_speed:     resd 1

section .text

; ================================================================
; core_usb_handle_port_change : Analyse l'état d'un port USB
; Entrée : RDI = Port ID
; ================================================================
core_usb_handle_port_change:
    push rbx
    push rcx
    push rdx

    mov rax, rdi

    ; Calculer l'adresse du registre PORTSC correspondant
    mov rbx, qword [rel op_base]
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
    PRINT_INLINE "[USB Hub] PORT : Périphérique CONNECTÉ !"

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

    PRINT_INLINE "[USB Hub] PORT : Reset termine, port actif et prêt !"

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
    LOG_HEX "[USB Hub] Vitesse du port (1=FS, 2=LS, 3=HS, 4=SS) : ", rax

    ; Demander un Slot ID pour le nouveau périphérique
    mov dword [rel device_init_state], DEV_STATE_WAIT_SLOT
    PRINT_INLINE "[USB Hub] Demande de Slot pour le device..."
    call hcd_cmd_enable_slot

    jmp .done

.device_unplugged:
    PRINT_INLINE "[USB Hub] PORT : Périphérique DÉCONNECTÉ !"

    PRINT_INLINE "[USB Hub] Demande de désactiver Slot du device..."
    call hcd_cmd_disable_slot
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
