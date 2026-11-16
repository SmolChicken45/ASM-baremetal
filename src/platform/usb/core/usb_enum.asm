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

; ---------------------------------------------------------------------------
; IMPORTATIONS
; ---------------------------------------------------------------------------
extern hcd_tr_enqueue
extern doorbell_base
extern core_usb_alloc_endpoint


section .text
; =============================================================================
; INTERFACE PUBLIQUE
; =============================================================================
; -----------------------------------------------------------------------------
; core_usb_get_device_desc
; Deomande le descripteur d'appareil standard (18 octets) sur l'EP0
; Entrée : RDI = usb_device_t*
; -----------------------------------------------------------------------------
core_usb_get_device_desc:
    push r12
    mov r12, rdi
    ; L'anneau de l'EP0 est toujours à l'index DCI 1
    mov r8, qword [r12 + usb_device_t.endpoints + 1 * 8]
    lea rdi, [r8 + usb_endpoint_t.tr_mgr]
    ; Setup Stage (TRB 1)
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
    lea rax, [r12 + usb_device_t.device_desc]
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

    ; Sonner le doorbell cible 1 (EP0)
    mov rdx, qword [rel doorbell_base]
    movzx ecx, byte [r12 + usb_device_t.slot_id]
    mov dword [rdx + rcx * 4], 1
    pop r12
    ret

; -----------------------------------------------------------------------------
; core_usb_get_config_desc_9
; Demande les 9 premiers octest pour lire wTotalLength
; Entrée : RDI = usb_device_t*
; -----------------------------------------------------------------------------
core_usb_get_config_desc_9:
    push r12
    mov r12, rdi
    ; Setup Stage
    mov r8, qword [r12 + usb_device_t.endpoints + 1 * 8]
    lea rdi, [r8 + usb_endpoint_t.tr_mgr]

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
    lea rax, [r12 + usb_device_t.config_desc]
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
    movzx ecx, byte [r12 + usb_device_t.slot_id]
    mov dword [rdx + rcx * 4], 1
    pop r12
    ret

; -----------------------------------------------------------------------------
; core_usb_get_config_desc_full
; Lit l'arbre de configuration complet
; Entrée :
;       RDI = usb_device_t*
;       RSI = wTotalLength
; -----------------------------------------------------------------------------
core_usb_get_config_desc_full:
    ; On sauvegarde la longueur car on va en avoir besoin pour le Data Stage
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi

    ; Setup Stage
    mov r8, qword [r12 + usb_device_t.endpoints + 1 * 8]
    lea rdi, [r8 + usb_endpoint_t.tr_mgr]

    ; Construire le paramètre avec la longueur dynamique
    ; Le format attendu est : (wLength << 48) | 0x0000000002000680
    mov rax, r13
    shl rax, 48
    mov rcx, (USB_DESC_CONFIGURATION << 24) | (USB_REQ_GET_DESCRIPTOR << 8) | (USB_REQ_DIR_IN | USB_REQ_TYPE_STD | USB_REQ_REC_DEVICE)
    or rax, rcx

    mov r8d, 8
    mov r9d, (TRB_TYPE_SETUP_STAGE << TRB_TYPE_SHIFT) | (TRT_IN_DATA << TRB_SETUP_TRT_SHIFT) | TRB_CTRL_IDT_BIT
    call hcd_tr_enqueue

    ; Data Stage
    lea rax, [r12 + usb_device_t.config_desc]
    VIRT_TO_PHYS rax

    mov r8d, r13d                   ; Transfer Length
    mov r9d, (TRB_TYPE_DATA_STAGE << TRB_TYPE_SHIFT) | TRB_CTRL_DIR_IN_BIT  ; IN Data
    call hcd_tr_enqueue

    ; Status Stage
    xor rax, rax
    xor r8d, r8d
    mov r9d, (TRB_TYPE_STATUS_STAGE << TRB_TYPE_SHIFT) | TRB_CTRL_DIR_OUT_BIT | TRB_CTRL_IOC_BIT ; IOC = 1
    call hcd_tr_enqueue

    ; Sonner e doorbell
    mov rdx, qword [rel doorbell_base]
    movzx ecx, byte [r12 + usb_device_t.slot_id]
    mov dword [rdx + rcx * 4], 1
    pop r13
    pop r12
    ret

; -----------------------------------------------------------------------------
; core_usb_set_config
; Active le périphérique en sélectionnant la configuration 1
; Entrée : RDI = usb_device_t*
; -----------------------------------------------------------------------------
core_usb_set_config:
    push r12
    mov r12, rdi
    ; Setup Stage
    mov r8, qword [r12 + usb_device_t.endpoints + 1 * 8]
    lea rdi, [r8 + usb_endpoint_t.tr_mgr]

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
    movzx ecx, byte [r12 + usb_device_t.slot_id]
    mov dword [rdx + rcx * 4], 1
    pop r12
    ret

; -----------------------------------------------------------------------------
; core_usb_parse_config
; Analyse la structure arborescente du buffer de configuration
; Entrée : RDI = usb_device_t*
; -----------------------------------------------------------------------------
core_usb_parse_config:
    push rbx
    push r12
    push r13
    push r14

    mov r12, rdi
    lea rbx, [r12 + usb_device_t.config_desc]
    movzx r13, word [rbx + USB_DESC_CFG_TOTALLEN_OFS]   ; wTotalLength
    xor rdx, rdx

.parse_loop:
    cmp rdx, r13
    jge .end_parsing

    movzx r14, byte [rbx + rdx]     ; AL = bLength
    test r14, r14
    jz .invalid_desc   ; AntiBoucle

    mov cl, byte [rbx + rdx + USB_DESC_EP_TYPE_OFS]

    cmp cl, USB_DESC_ENDPOINT                    ; 5 = EndpointDescriptor
    je .found_endpoint

    cmp cl, USB_DESC_INTERFACE
    je .found_interface

.next_desc:
    add rdx, r14                    ; Sauter au descripteur suivant
    jmp .parse_loop

.found_interface:
    movzx r8, byte [rbx + rdx + USB_DESC_INTF_CLASS_OFS]

    cmp r8b, USB_CLASS_HID
    je .check_hid

    ; cmp r8b, USB_CLASS_MASS_STORAGE
    ; je .check_msd

    jmp .next_desc

.check_hid:
    movzx r9, byte [rbx + rdx + USB_DESC_INTF_PROTOCOL_OFS]

    cmp r9b, HID_PROTOCOL_MOUSE
    je .is_mouse

    cmp r9b, HID_PROTOCOL_KEYBOARD
    je .is_keyboard

    jmp .next_desc

.is_mouse:
    PRINT_INLINE "[USB Router] Souris HID détectée !"
    ; TODO: Assigner le pilote souris dans la structure device
    jmp .next_desc

.is_keyboard:
    PRINT_INLINE "[USB Router] Clavier HID détecté !"
    ; TODO: Assigner le pilote de clavier dans la structure device
    jmp .next_desc

.found_endpoint:
    PRINT_INLINE "[USB Core] Endpoint Descriptor trouvé !"

    ; Lire l'adresse (ex : 0x81 = IN, EP 1)
    movzx r8, byte [rbx + rdx + USB_DESC_EP_ADDR_OFS]

    ; Calcul du DCI = (EP_Number * 2) + (Direction == IN ? 1 : 0)
    mov r9, r8
    and r9, 0x0F    ; (enlever le Direction)
    shl r9, 1       ; * 2

    test r8, 0x80
    jz .dci_calculated
    inc r9

.dci_calculated:
    ; R9 = DCI
    LOG_HEX "   DCI calculé : ", r9

    ; Allouer l'Endpoint mémoire via usb_pool
    mov rdi, r12
    mov rsi, r9
    push rdx
    push r9
    call core_usb_alloc_endpoint
    pop r9
    pop rdx

    test rax, rax
    jz .ep_alloc_fail
    mov r8, rax
    ; R12 = usb_device_t*
    ; r8 = usb_endpoint_t*
    ; r9 = DCI
    ; RBX + RDX

    ; Allumer le bit correspondant au DCI dans l'Input Control COntext (Add Flags
    mov r10, qword [r12 + usb_device_t.input_ctx_virt]

    mov ecx, r9d
    mov eax, 1
    shl eax, cl
    or eax, 1 ; SLot Context à 1
    mov dword [r10 + CTX_ADD_FLAGS], eax
    mov dword [r10 + 0x00], 0

    ; Mettre à jour "Context Entries" dans le Slot COntext (Offset 0x20)
    ; Le xHCI exige que ce champ contienne le DCI le plus élevé actif
    mov eax, dword [r10 + CTX_SLOT]
    mov ecx, eax
    shr ecx, SLOT_ENTRIES_SHIFT
    and ecx, 0x1F       ; Actuel DCI max
    cmp r9d, ecx
    jle .skip_entries_update

    and eax, ~(0x1F << SLOT_ENTRIES_SHIFT)
    mov ecx, r9d
    shl ecx, SLOT_ENTRIES_SHIFT
    or eax, ecx
    mov dword [r10 + CTX_SLOT], eax

.skip_entries_update:
    ; Calculer le pointeur vers l'Endpoint Context spécifique
    ; Formule : Pointeur = Input Context + ((DCI + 1) * 32)
    mov r11, r9
    inc r11
    shl r11, 5
    add r11, r10

    ; Déterminer le Type xHCI (0 à 7)
    movzx eax, byte [rbx + rdx + USB_DESC_EP_ATTR_OFS]
    and eax, 0x03           ; Garder le Type

    test byte [rbx + rdx + USB_DESC_EP_ADDR_OFS], 0x80 ; est-ce IN?
    jz .ep_is_out
    or eax, 4               ; IN -> Type_xHCI = Type_USB + 4
.ep_is_out:
    mov r10d, eax           ; Type xHCI final

    ; Isoler le Type USB
    movzx ecx, byte [rbx + rdx + USB_DESC_EP_ATTR_OFS]
    and ecx, 0x03

    ; Préparer le DWORD 0
    xor eax, eax

    ; Vérifier si c'est un endpoint Interrupt
    cmp ecx, 3
    jne .write_dword0

    mov eax, (6 << 16)

.write_dword0:
    ; Écrire le DWORD 0 dans l'Endpoint Context
    mov dword [r11 + 0x00], eax

    ; Lire le Max Paket Size du descripteur
    movzx ecx, word [rbx + rdx + USB_DESC_EP_MAXPKT_OFS]

    ; Écrire le DWORD 1 de l'Endpoint COntext
    ; Error Count (Bit 1-2) = 3 | Type (Bit 3-5) | Max Packet (Bit 16-31)
    mov eax, (3 << 1)
    shl r10d, 3
    or eax, r10d
    mov r10d, ecx
    shl r10d, 16
    or eax, r10d
    mov dword [r11 + 0x04], eax

    ; Écrire les DWORD 2 & 3 L TRDP
    mov rax, qword [r8 + usb_endpoint_t.tr_mgr + tr_manager_t.base_phys]
    or rax, 1       ; Activer le bit DCS
    mov dword [r11 + 0x08], eax
    shr rax, 32
    mov dword [r11 + 0x0C], eax

    ; Écrire le DWORD 4  : Average TRB Length (8) et Max ESIT Payload (Max Packet Size)
    ; Requis pour Isoch/Interrept, inoffensif pour Bulk/Control
    mov eax, 8  ;Avg TRB Length = 8
    shl ecx, 16
    or eax, ecx
    mov dword [r11 + 0x10], eax

    jmp .next_desc

.ep_alloc_fail:
    PRINT_INLINE "[USB Core] ERREUR : Impossivle d'allouer l'Endpoint !"
    jmp .next_desc

.invalid_desc:
    PRINT_INLINE "[USB Core] Obtenu un Descriptor de longueur 0"
    ret
.end_parsing:
    PRINT_INLINE "[USB Core] Fin de l'analyse de la configuration."
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
