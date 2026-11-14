[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/memory.inc"
%include "platform/xhci.inc"

; EXPORTATIONS
global xhci_get_device_descriptor
global xhci_get_config_descriptor_9
global xhci_get_config_descriptor_full
global device_desc_buffer
global config_desc_buffer

; IMPORTATIONS
extern tr_enqueue
extern ep0_mgr
extern current_slot_id
extern xhci_doorbell_base
extern device_init_state

; Données
section .bss
align 64
device_desc_buffer: resb 64 ; Le buffer où le descripteur sera copié par le xHCI
config_desc_buffer: resb 256
section .text

;Envoie une requête "Get Descriptor (Device)" sur l'EP0
xhci_get_device_descriptor:

    ; Setup Stage (TRB 1)
    lea rdi, [rel ep0_mgr]

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
    call tr_enqueue

    ; Data Stage (TRB 2)
    lea rax, [rel device_desc_buffer]
    VIRT_TO_PHYS rax

    mov r8d, 18         ; Transfer Length = 18
    ; Control : Type = 3, DIR = 1, IOC = 0
    mov r9d, (3 << 10) | (1 << 16)
    call tr_enqueue

    ; Status Stage (TRB 3)
    xor rax, rax        ; Paramètre = 0
    xor r8d, r8d        ; Status = 0
    ; Control : Type = 4, DIR = 0, IOC = 1 (Déclenche l'Event)
    mov r9d, (4 << 10) | (0 << 16) | (1 << 5)
    call tr_enqueue

    ; Sonner le doorbell
    mov rdx, qword [rel xhci_doorbell_base]
    mov ecx, dword [rel current_slot_id]

    ; Doorbell cible = 1 (EP0)
    mov dword [rdx + rcx * 4], 1

    ; Mettre à jour l'état de la machine à états de l'init USB
    mov dword [rel device_init_state], DEV_STATE_WAIT_DESC
    PRINT_INLINE "[xHCI] Get Device Descriptor envoye !"

    ret

; Demande les 9 premiers octest pour trouver wTotalLength
xhci_get_config_descriptor_9:
    ; Setup Stage
    lea rdi, [rel ep0_mgr]

    ; Paramètre :
    ;   bmRequestType = 0x80
    ;   bRequest =      0x06
    ;   wValue =        0x0200
    ;   wIndex =        0x00
    ;   wLenght =       0x09
    mov rax, 0x0009000002000680
    mov r8d, 8
    mov r9d, (2 << 10) | (3 << 16) | (1 << 6)
    call tr_enqueue

    ; Data Stage
    lea rax, [rel config_desc_buffer]
    VIRT_TO_PHYS rax

    mov r8d, 9      ; On demande exactement 9 octet
    mov r9d, (3 << 10) | (1 << 16)  ; IN Data
    call tr_enqueue

    ; Status Stage
    xor rax, rax
    xor r8d, r8d
    mov r9d, (4 << 10) | (0 << 16) | (1 << 5)   ; IOC = 1
    call tr_enqueue

    ; Sonner le doorbell
    mov rdx, qword [rel xhci_doorbell_base]
    mov ecx, dword [rel current_slot_id]
    mov dword [rdx + rcx * 4], 1

    mov dword [rel device_init_state], DEV_STATE_WAIT_CONF9
    PRINT_INLINE "[xHCI] Get Config Descriptor (9 Bytes) envoye !"

    ret

; xhci_get_config_descriptor_full
; Lit l'arbre de configuration complet
; Paramètre attendu : R10 = wTotalLength
xhci_get_config_descriptor_full:
    ; On sauvegarde la longueur car on va en avoir besoin pour le Data Stage
    push r10

    ; Setup Stage
    lea rdi, [rel ep0_mgr]

    ; Construire le paramètre avec la longueur dynamique
    ; Le format attendu est : (wLength << 48) | 0x0000000002000680
    mov rax, r10
    shl rax, 48
    mov rcx, 0x0000000002000680
    or rax, rcx

    mov r8d, 8
    mov r9d, (2 << 10) | (3 << 16) | (1 << 6)
    call tr_enqueue

    ; Data Stage
    lea rax, [rel config_desc_buffer]
    VIRT_TO_PHYS rax

    pop r10
    mov r8d, r10d                   ; Transfer Length
    mov r9d, (3 << 10) | (1 << 16)  ; IN Data
    call tr_enqueue

    ; Status Stage
    xor rax, rax
    xor r8d, r8d
    mov r9d, (4 << 10) | (0 << 16) | (1 << 5) ; IOC = 1
    call tr_enqueue

    ; Sonner e doorbell
    mov rdx, qword [rel xhci_doorbell_base]
    mov ecx, dword [rel current_slot_id]
    mov dword [rdx + rcx * 4], 1

    ; Mettre à jour l'état
    mov dword [rel device_init_state], DEV_STATE_WAIT_CONF_FULL
    PRINT_INLINE "[xHCI] Get Config Descriptor Full envoyé !"

    ret