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
    ;   bmRequestType = 0x80
    ;   bRequest =      0x06
    ;   wValue =        0x0100
    ;   wIndex =        0x00
    ;   wLength =       18
    mov rax, 0x0012000001000680
    mov r8d, 8          ; Transfer Length = 8
    ; Control : Type = 2, TRT = 3, IDT = 1, IOC = 0
    mov r9d, (2 << 10) | (3 << 16) | (1 << 6)
    call hcd_tr_enqueue

    ; Data Stage (TRB 2)
    lea rax, [rel device_desc_buffer]
    VIRT_TO_PHYS rax

    mov r8d, 18         ; Transfer Length = 18
    ; Control : Type = 3, DIR = 1, IOC = 0
    mov r9d, (3 << 10) | (1 << 16)
    call hcd_tr_enqueue

    ; Status Stage (TRB 3)
    xor rax, rax        ; Paramètre = 0
    xor r8d, r8d        ; Status = 0
    ; Control : Type = 4, DIR = 0, IOC = 1 (Déclenche l'Event)
    mov r9d, (4 << 10) | (0 << 16) | (1 << 5)
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
    ;   bmRequestType = 0x80
    ;   bRequest =      0x06
    ;   wValue =        0x0200
    ;   wIndex =        0x00
    ;   wLenght =       0x09
    mov rax, 0x0009000002000680
    mov r8d, 8
    mov r9d, (2 << 10) | (3 << 16) | (1 << 6)
    call hcd_tr_enqueue

    ; Data Stage
    lea rax, [rel config_desc_buffer]
    VIRT_TO_PHYS rax

    mov r8d, 9      ; On demande exactement 9 octet
    mov r9d, (3 << 10) | (1 << 16)  ; IN Data
    call hcd_tr_enqueue

    ; Status Stage
    xor rax, rax
    xor r8d, r8d
    mov r9d, (4 << 10) | (0 << 16) | (1 << 5)   ; IOC = 1
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
    mov rcx, 0x0000000002000680
    or rax, rcx

    mov r8d, 8
    mov r9d, (2 << 10) | (3 << 16) | (1 << 6)
    call hcd_tr_enqueue



    ; Data Stage
    lea rax, [rel config_desc_buffer]

    LOG_HEX "[DEBUG] Virtual Addr device_desc_buffer: ", rax

    VIRT_TO_PHYS rax

    LOG_HEX "[DEBUG] Physical Addr sent to xHCI: ", rax

    pop r10
    mov r8d, r10d                   ; Transfer Length
    mov r9d, (3 << 10) | (1 << 16)  ; IN Data
    call hcd_tr_enqueue

    ; Status Stage
    xor rax, rax
    xor r8d, r8d
    mov r9d, (4 << 10) | (0 << 16) | (1 << 5) ; IOC = 1
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
    mov rax, 0x0000000000010900
    mov r8d, 8      ; Longueur de la requête = 8
    ; Control : Type = 2, TRT = 0 (No Data), IDT = 1, IOC = 0
    mov r9d, (2 << 10) | (0 << 16) | (1 << 6)
    call hcd_tr_enqueue

    ; Status Stage
    xor rax, rax
    xor r8d, r8d
    ; Control : Type = 4, DIR = 1 (IN), IOC = 1
    mov r9d, (4 << 10) | (1 << 16) | (1 << 5)
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
    movzx rcx, word [rbx + 2]   ; wTotalLength
    xor rdx, rdx

.parse_loop:
    cmp rdx, rcx
    jge .end_parsing

    movzx rax, byte [rbx + rdx]     ; AL = bLength
    test al, al
    jz .invalid_desc   ; AntiBoucle

    cmp byte [rbx + rdx + 1], 0x05                    ; 5 = EndpointDescriptor
    je .found_endpoint

    add rdx, rax                    ; Sauter au descripteur suivant
    jmp .parse_loop

.found_endpoint:
    PRINT_INLINE "[USB Core] Endpoint Descriptor trouvé !"

    ; Lire l'adresse de l'Endpoint
    movzx eax, byte [rbx + rdx + 2]
    LOG_HEX "Adresse EP (Bit 7=IN) : ", rax

    ; Lire les attributs (0x03 = Interrupt)
    movzx eax, byte [rbx + rdx + 3]
    LOG_HEX "Attributs (3=INT) : ", rax

    ; Lire le Max Packet Size
    movzx eax, word [rbx + rdx + 4]
    LOG_HEX "Max Packet Size : ", rax

    ; Lire l'intervalle de polling
    movzx eax, byte [rbx + rdx + 6]
    LOG_HEX "Intervalle (ms) : ", rax

    movzx rax, byte [rbx + rdx]
    add rdx, rax
    jmp .parse_loop

.invalid_desc:
    PRINT_INLINE "[USB Core] Obtenu un Descriptor de longueur 0"
    ret
.end_parsing:
    PRINT_INLINE "[USB Core] Fin de l'analyse de la configuration."
    ret
