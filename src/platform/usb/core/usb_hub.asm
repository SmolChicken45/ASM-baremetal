[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/xhci.inc"

; ================================================================
; EXPORTATIONS
; ================================================================
global core_usb_handle_port_change


; ================================================================
; EXPORTATIONS
; ================================================================
extern op_base                          ; hcd/init.asm
extern hcd_cmd_enable_slot              ; hcd/cmd.asm
extern hcd_cmd_disable_slot             ; hcd/cmd.asm
extern device_init_state                ; core/event.asm
extern core_usb_alloc_device            ; core/usb_pool.asm
extern core_usb_alloc_endpoint          ; core/usb_pool.asm
extern core_usb_free_device             ; core/usb_pool.asm
extern core_usb_get_device_by_port      ; core/usb_pool.asm

section .text

; ================================================================
; core_usb_handle_port_change : Analyse l'état d'un port USB
; Entrée : RDI = Port ID
; ================================================================
core_usb_handle_port_change:
    push rbx
    push r12

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

    call core_usb_alloc_device
    test rax, rax
    jz .erreur_memoire

    mov r12, rax    ; Pointeur vers usb_device_t

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

    mov eax, edi
    mov byte [r12 + usb_device_t.port_id], al

    ; Lecture de la vitesse du périphérique
    mov eax, dword [rbx]
    shr eax, XHCI_PORTSC_SPEED_SHIFT     ; Amener le bit 10 à la pos 0
    and eax, XHCI_PORTSC_SPEED_MASK   ; Masquer pour garder 4 bits

    mov byte [r12 + usb_device_t.speed], al
    LOG_HEX "[USB Hub] Vitesse du port (1=FS, 2=LS, 3=HS, 4=SS) : ", rax

    ; Allouer le EP0
    mov rdi, r12
    mov rsi, 1
    call core_usb_alloc_endpoint
    test rax, rax
    jz .erreur_memoire

    ; Demander un Slot ID pour le nouveau périphérique
    mov dword [r12 + usb_device_t.state], DEV_STATE_WAIT_SLOT
    PRINT_INLINE "[USB Hub] Demande de Slot pour le device..."
    mov rdi, r12
    call hcd_cmd_enable_slot

    jmp .done

.device_unplugged:
    PRINT_INLINE "[USB Hub] PORT : Périphérique DÉCONNECTÉ !"

    call core_usb_get_device_by_port
    test rax, rax
    jz .ack_disconnect

    mov r12, rax

    movzx edi, byte [r12 + usb_device_t.slot_id]
    PRINT_INLINE "[USB Hub] Demande de désactiver Slot du device..."
    call hcd_cmd_disable_slot

    ; Libérer la mémoire
    mov rdi, r12
    call core_usb_free_device
    PRINT_INLINE "[USB Hub] Appareil supprimé du système de mémoire."
.ack_disconnect:
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
    jmp .done

.erreur_memoire:
    PRINT_INLINE "[USB Hub] ERREUR FATALE : Allocation mémoire USB impossible !"

.done:
    pop r12
    pop rbx
    ret
