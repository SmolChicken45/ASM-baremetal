[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/memory.inc"
%include "platform/xhci.inc"

; ---------------------------------------------------------------------------
; EXPORTATIONS
; ---------------------------------------------------------------------------
global core_usb_get_device_desc
global core_usb_get_config_desc_9
global core_usb_get_config_desc_full
global core_usb_set_config
global core_usb_parse_config

global device_desc_buffer
global config_desc_buffer

; ---------------------------------------------------------------------------
; IMPORTATIONS
; ---------------------------------------------------------------------------
extern hcd_tr_enqueue
extern core_usb_ep0_mgr
extern current_slot_id
extern doorbell_base


; ---------------------------------------------------------------------------
; DONNÉES GLOBALES ET BUFFERS
; ---------------------------------------------------------------------------
section .bss
align 64
device_desc_buffer: resb 64 ; Le buffer où le descripteur sera copié par le xHCI
align 64
config_desc_buffer: resb 256

section .text
; =============================================================================
; INTERFACE PUBLIQUE
; =============================================================================
; -----------------------------------------------------------------------------
; core_usb_get_device_desc
; Deomande le descripteur d'appareil standard (18 octets) sur l'EP0
; -----------------------------------------------------------------------------
core_usb_get_device_desc:

    ; Setup Stage (TRB 1)
    lea rdi, [rel core_usb_ep0_mgr]

    ; Paramètres :
    ;   bmRequestType: IN | STD | DEVICE (0x80)
    ;   bRequest: GET_DESCRIPTOR (0x06)
    ;   wValue: DEVICE_DESC (0x01) << 8 | Index (0x00)
    ;   wIndex: 0x0000
    ;   wLength: 18 (0x0012)
    mov rax, ((18) << 48) | (USB_DESC_DEVICE << 24) | (USB_REQ_GET_DESCRIPTOR << 8) | (USB_REQ_DIR_IN | USB_REQ_TYPE_STD | USB_REQ_REC_DEVICE)
    mov r8d, 8          ; Transfer Length = 8
    ; Control : Type = Setup, TRT = IN Data, IDT = 1, IOC = 0
    mov r9d, (TRB_TYPE_SETUP_STAGE << TRB_TYPE_SHIFT) | (TRT_IN_DATA << TRB_SETUP_TRT_SHIFT) | TRB_CTRL_IDT_BIT
    call hcd_tr_enqueue

    ; Data Stage (TRB 2)
    lea rax, [rel device_desc_buffer]
    VIRT_TO_PHYS rax

    mov r8d, 18         ; Transfer Length = 18
    ; Control : Type = Data, DIR = 1, IOC = 0
    mov r9d, (TRB_TYPE_DATA_STAGE << TRB_TYPE_SHIFT) | TRB_CTRL_DIR_IN_BIT
    call hcd_tr_enqueue

    ; Status Stage (TRB 3)
    xor rax, rax        ; Paramètre = 0
    xor r8d, r8d        ; Status = 0
    ; Control : Type = 4, DIR = 0, IOC = 1 (Déclenche l'Event)
    mov r9d, (TRB_TYPE_STATUS_STAGE << TRB_TYPE_SHIFT) | TRB_CTRL_DIR_OUT_BIT | TRB_CTRL_IOC_BIT
    call hcd_tr_enqueue

    ; Sonner le doorbell cible 1
    mov rdx, qword [rel doorbell_base]
    mov ecx, dword [rel current_slot_id]
    mov dword [rdx + rcx * 4], 1

    ret

; -----------------------------------------------------------------------------
; core_usb_get_config_desc_9
; Demande les 9 premiers octest pour lire wTotalLength
; -----------------------------------------------------------------------------
core_usb_get_config_desc_9:
    ; Setup Stage
    lea rdi, [rel core_usb_ep0_mgr]

    ; Paramètre :
    ;   bmRequestType: IN | STD | DEVICE (0x80)
    ;   bRequest: GET_DESCRIPTOR (0x06)
    ;   wValue = CONFIGURATION_DESC (0x02) << 8 | Index (0x00)
    ;   wIndex = 0x0000
    ;   wLenght = 0x09
    mov rax, ((0x09) << 48) | (USB_DESC_CONFIGURATION << 24) | (USB_REQ_GET_DESCRIPTOR << 8) | (USB_REQ_DIR_IN | USB_REQ_TYPE_STD | USB_REQ_REC_DEVICE)
    mov r8d, 8
    mov r9d, (TRB_TYPE_SETUP_STAGE << TRB_TYPE_SHIFT) | (TRT_IN_DATA << TRB_SETUP_TRT_SHIFT) | TRB_CTRL_IDT_BIT
    call hcd_tr_enqueue

    ; Data Stage
    lea rax, [rel config_desc_buffer]
    VIRT_TO_PHYS rax

    mov r8d, 9      ; On demande exactement 9 octet
    mov r9d, (TRB_TYPE_DATA_STAGE << TRB_TYPE_SHIFT) | TRB_CTRL_DIR_IN_BIT  ; IN Data
    call hcd_tr_enqueue

    ; Status Stage
    xor rax, rax
    xor r8d, r8d
    mov r9d, (TRB_TYPE_STATUS_STAGE << TRB_TYPE_SHIFT) | TRB_CTRL_DIR_OUT_BIT | TRB_CTRL_IOC_BIT   ; IOC = 1
    call hcd_tr_enqueue

    ; Sonner le doorbell
    mov rdx, qword [rel doorbell_base]
    mov ecx, dword [rel current_slot_id]
    mov dword [rdx + rcx * 4], 1

    ret

; -----------------------------------------------------------------------------
; core_usb_get_config_desc_full
; Lit l'arbre de configuration complet
; Paramètre : R10 = wTotalLength
; -----------------------------------------------------------------------------
core_usb_get_config_desc_full:
    ; On sauvegarde la longueur car on va en avoir besoin pour le Data Stage
    push r10

    ; Setup Stage
    lea rdi, [rel core_usb_ep0_mgr]

    ; Construire le paramètre avec la longueur dynamique
    ; Le format attendu est : (wLength << 48) | 0x0000000002000680
    mov rax, r10
    shl rax, 48
    mov rcx, (USB_DESC_CONFIGURATION << 24) | (USB_REQ_GET_DESCRIPTOR << 8) | (USB_REQ_DIR_IN | USB_REQ_TYPE_STD | USB_REQ_REC_DEVICE)
    or rax, rcx

    mov r8d, 8
    mov r9d, (TRB_TYPE_SETUP_STAGE << TRB_TYPE_SHIFT) | (TRT_IN_DATA << TRB_SETUP_TRT_SHIFT) | TRB_CTRL_IDT_BIT
    call hcd_tr_enqueue

    ; Data Stage
    lea rax, [rel config_desc_buffer]
    VIRT_TO_PHYS rax

    pop r10
    mov r8d, r10d                   ; Transfer Length
    mov r9d, (TRB_TYPE_DATA_STAGE << TRB_TYPE_SHIFT) | TRB_CTRL_DIR_IN_BIT  ; IN Data
    call hcd_tr_enqueue

    ; Status Stage
    xor rax, rax
    xor r8d, r8d
    mov r9d, (TRB_TYPE_STATUS_STAGE << TRB_TYPE_SHIFT) | TRB_CTRL_DIR_OUT_BIT | TRB_CTRL_IOC_BIT ; IOC = 1
    call hcd_tr_enqueue

    ; Sonner e doorbell
    mov rdx, qword [rel doorbell_base]
    mov ecx, dword [rel current_slot_id]
    mov dword [rdx + rcx * 4], 1

    ret

; -----------------------------------------------------------------------------
; core_usb_set_config
; Active le périphérique en sélectionnant la configuration 1
; -----------------------------------------------------------------------------
core_usb_set_config:
    ; Setup Stage
    lea rdi, [rel core_usb_ep0_mgr]

    ; Paramètres :
    ;   bmResquestType = 0x80
    ;   bRequest =       0x09 (SET_CONF)
    ;   wValue =         0x0001 (Config 1)
    ;   wIndex =         0x00
    ;   wLength =        0x00
    mov rax, (USB_CFG_VAL_DEFAULT << 16) | (USB_REQ_SET_CONFIGURATION << 8) | (USB_REQ_DIR_OUT | USB_REQ_TYPE_STD | USB_REQ_REC_DEVICE)
    mov r8d, 8      ; Longueur de la requête = 8
    ; Control : Type = 2, TRT = 0 (No Data), IDT = 1, IOC = 0
    mov r9d, (TRB_TYPE_SETUP_STAGE << TRB_TYPE_SHIFT) | (TRT_NO_DATA << TRB_SETUP_TRT_SHIFT) | TRB_CTRL_IDT_BIT
    call hcd_tr_enqueue

    ; Status Stage
    xor rax, rax
    xor r8d, r8d
    ; Control : Type = 4, DIR = 1 (IN), IOC = 1
    mov r9d, (TRB_TYPE_STATUS_STAGE << TRB_TYPE_SHIFT) | TRB_CTRL_DIR_IN_BIT | TRB_CTRL_IOC_BIT
    call hcd_tr_enqueue

    ; Sonner le Doorbell
    mov rdx, qword [rel doorbell_base]
    mov ecx, dword [rel current_slot_id]
    mov dword [rdx + rcx * 4], 1

    ret

; -----------------------------------------------------------------------------
; core_usb_parse_config
; Analyse la structure arborescente du buffer de configuration
; -----------------------------------------------------------------------------
core_usb_parse_config:
    lea rbx, [rel config_desc_buffer]
    movzx rcx, word [rbx + USB_DESC_CFG_TOTALLEN_OFS]   ; wTotalLength
    xor rdx, rdx

.parse_loop:
    cmp rdx, rcx
    jge .end_parsing

    movzx rax, byte [rbx + rdx]     ; AL = bLength
    test al, al
    jz .invalid_desc   ; AntiBoucle

    cmp byte [rbx + rdx + USB_DESC_EP_TYPE_OFS], USB_DESC_ENDPOINT                    ; 5 = EndpointDescriptor
    je .found_endpoint

    add rdx, rax                    ; Sauter au descripteur suivant
    jmp .parse_loop

.found_endpoint:
    PRINT_INLINE "[USB Core] Endpoint Descriptor trouvé !"

    ; Lire l'adresse de l'Endpoint
    movzx eax, byte [rbx + rdx + USB_DESC_EP_ADDR_OFS]
    LOG_HEX "Adresse EP (Bit 7=IN) : ", rax

    ; Lire les attributs (0x03 = Interrupt)
    movzx eax, byte [rbx + rdx + USB_DESC_EP_ATTR_OFS]
    LOG_HEX "Attributs (3=INT) : ", rax

    ; Lire le Max Packet Size
    movzx eax, word [rbx + rdx + USB_DESC_EP_MAXPKT_OFS]
    LOG_HEX "Max Packet Size : ", rax

    ; Lire l'intervalle de polling
    movzx eax, byte [rbx + rdx + USB_DESC_EP_INTERVAL_OFS]
    LOG_HEX "Intervalle (ms) : ", rax

    movzx rax, byte [rbx + rdx + USB_DESC_EP_LENGTH_OFS]
    add rdx, rax
    jmp .parse_loop

.invalid_desc:
    PRINT_INLINE "[USB Core] Obtenu un Descriptor de longueur 0"
    ret
.end_parsing:
    PRINT_INLINE "[USB Core] Fin de l'analyse de la configuration."
    ret
