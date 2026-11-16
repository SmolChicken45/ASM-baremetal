[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/xhci.inc"
%include "platform/memory.inc"

; ================================================================
; EXPORTATIONS
; ================================================================
global core_usb_handle_cmd_completion
global core_usb_handle_transfer_completion
global device_init_state
global current_slot_id

; ================================================================
; IMPORTATIONS
; ================================================================
extern core_usb_dcbaa                   ; hcd/init.asm
extern core_usb_setup_device_context    ; core/usb_device.asm
extern core_usb_get_device_desc         ; core/usb_device.asm
extern core_usb_get_config_desc_9       ; core/usb_device.asm
extern core_usb_get_config_desc_full    ; core/usb_device.asm
extern core_usb_set_config              ; core/usb_device.asm
extern core_usb_parse_config            ; core/usb_enum.asm

extern hcd_cmd_address_device           ; hcd/cmd.asm
extern hcd_cmd_configure_endpoint       ; hcd/cmd.asm

extern core_usb_get_device_by_slot      ; core/usb_pool.asm
extern core_usb_get_device_waiting_slot ; core/usb_pool.asm


; TODO Temporaire à déplacer dans class/usb_hid.asm
extern xhci_configure_ep1_in
extern xhci_submit_mouse_read
extern mouse_data_buffer

section .bss
align 4
device_init_state:  resd 1
current_slot_id:    resd 1

section .text

; ================================================================
; core_usb_handle_cmd_completion
; Entrée :
;       RDI = Completion Code
;       RSI = Slot ID
; ================================================================
core_usb_handle_cmd_completion:

    call core_usb_get_device_waiting_slot
    test rax, rax
    jnz .got_device

    push rdi
    mov rdi, rsi
    call core_usb_get_device_by_slot
    pop rdi
    test rax, rax
    jnz .got_device
    ret

.got_device:
    mov r12, rax

    mov eax, dword [r12 + usb_device_t.state]

    cmp eax, DEV_STATE_WAIT_SLOT
    je .handle_enable_slot_success

    cmp eax, DEV_STATE_WAIT_ADDR
    je .handle_address_device_success

    cmp eax, DEV_STATE_WAIT_CONF_EP
    je .handle_configure_ep_success

    ret


.handle_enable_slot_success:
    ; RSI contient Slot ID
    mov byte [r12 + usb_device_t.slot_id], sil
    LOG_HEX "[USB Core] Slot ID obtenu : ", rsi

    ; Création des context
    mov rdi, r12
    call core_usb_setup_device_context

    mov dword [r12 + usb_device_t.state], DEV_STATE_WAIT_ADDR
    PRINT_INLINE "[USB Core] Demande du Address device..."

    ; Lancer la commande matérielle Address Device
    mov rdi, r12
    call hcd_cmd_address_device
    ret

.handle_address_device_success:

    ; La commande a réussi, l'adresse USB a été attirbuée par le matéiel
    ; Le xHCI a écrit cette adresse dans le Slot Context de l'OUTPUT Context
    ; Le Slot COntext commence à l'offset 0x00 de l'Output COntext
    ; L'adresse USB est dans le DWORD 3
    mov r8, [r12 + usb_device_t.output_ctx_virt]
    mov eax, dword [r8 + 0x0C]
    and eax, 0xFF

    LOG_HEX "[USB Core] Adresse USB : ", rax

    mov dword [r12 + usb_device_t.state], DEV_STATE_WAIT_DESC
    PRINT_INLINE "[USB Core] Demande du Device Descriptor..."

    mov rdi, r12
    call core_usb_get_device_desc
    ret

.handle_configure_ep_success:
    PRINT_INLINE "[USB Core] Endpoint 1 Configuré !"
    mov dword [r12 + usb_device_t.state], DEV_STATE_IDLE

    ; Logique Souris Temporaire
    mov rdi, r12
    call xhci_submit_mouse_read
    ret

; ================================================================
; core_usb_handle_transfer_completion
; Entrée :
;       RDI = Completion Code
;       RSI = Pointeur Physique du TRB
;       RDX = SLOT ID
; ================================================================
core_usb_handle_transfer_completion:

    push rdi
    mov rdi, rdx
    call core_usb_get_device_by_slot
    test rax, rax
    pop rdi
    jnz .got_device
    ret

.got_device:
    mov r12, rax

    ; Logique de Souris Temporaire
    ; SI c'est un Short Packet c'est probablement la souris
    cmp rdi, 0x0D
    je .mouse_read_success

    ; Vérifier si on attendait le Device Descriptor
    mov eax, dword [r12 + usb_device_t.state]

    cmp eax, DEV_STATE_WAIT_DESC
    je .handle_device_desc_success

    cmp eax, DEV_STATE_WAIT_CONF9
    je .handle_conf9_success

    cmp eax, DEV_STATE_WAIT_CONF_FULL
    je .handle_conf_full_success

    cmp eax, DEV_STATE_WAIT_SET_CONF
    je .handle_set_conf_success

    PRINT_INLINE "[USB Core] Transfère Non-géré est détecté sur l'EP0"
    ret

.handle_device_desc_success:
    PRINT_INLINE "[USB Core] Descripteur de périphérique lu avec succès !"

    ; Charger l'adresse du buffer où le xHCI a écrit la réponse
    lea r8, [r12 + usb_device_t.device_desc]

    ; Vendor ID (2 bytes -> Offset 8)
    movzx eax, word [r8 + 8]
    LOG_HEX "   Vendor ID : ", rax
    ; Product ID (2 bytes -> offset 10)
    movzx eax, word [r8 + 10]
    LOG_HEX "   Product ID : ", rax
    ; Lire le Max Packet Size (offset 7)
    movzx eax, byte [r8 + 7]
    LOG_HEX "   Max Packet Size : ", rax

    mov dword [r12 + usb_device_t.state], DEV_STATE_WAIT_CONF9
    PRINT_INLINE "[USB Core] Demande de l'en-tête de configuration..."
    mov rdi, r12
    call core_usb_get_config_desc_9
    ret

.handle_conf9_success:
    PRINT_INLINE "[USB Core] En-tête de configuration lu !"
    lea r8, [r12 + usb_device_t.config_desc]

    ; Le wTotalLength est sur 2 octets à l'offset 2
    movzx eax, word [r8 + USB_DESC_CFG_TOTALLEN_OFS]
    LOG_HEX "wTotalLength trouvé : ", rax

    mov dword [r12 + usb_device_t.state], DEV_STATE_WAIT_CONF_FULL
    PRINT_INLINE "[USB Core] Demande de la configuration complet..."

    mov rdi, r12
    mov rsi, rax
    call core_usb_get_config_desc_full
    ret

.handle_conf_full_success:
    PRINT_INLINE "[USB Core] Arbre de configuration COMPLET lu en RAM !"

    mov dword [r12 + usb_device_t.state], DEV_STATE_WAIT_SET_CONF
    PRINT_INLINE "[USB Core] Set Configuration..."

    mov rdi, r12
    call core_usb_set_config
    ret

.handle_set_conf_success:
    PRINT_INLINE "[USB Core] SET CONFIGURATION réussi ! Périphérique ACTIF"
    ; Analyserl'arbre pour trouver les Endpoints
    mov rdi, r12
    call core_usb_parse_config

    mov dword [r12 + usb_device_t.state], DEV_STATE_WAIT_CONF_EP
    PRINT_INLINE "[USB Core] Configuration des Endpoints par le matériel..."
    mov rdi, r12
    call hcd_cmd_configure_endpoint
    ret

; ================================================================
; Logique Classe HID Souris (Temp)
; ================================================================
.mouse_read_success:
    PRINT_INLINE "[USB HID] Mouvement de souris detecté"

    lea rdi, [rel mouse_data_buffer]
    movzx eax, byte [rdi + 0]
    LOG_HEX "Boutons : ", rax
    movzx eax, byte [rdi + 1]
    LOG_HEX "Axe X : ", rax
    movzx eax, byte [rdi + 2]
    LOG_HEX "Axe Y : ", rax

    mov rdi, r12
    call xhci_submit_mouse_read
    ret