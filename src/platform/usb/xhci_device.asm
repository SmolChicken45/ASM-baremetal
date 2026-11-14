[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/memory.inc"
%include "platform/xhci.inc"

; EXPORTATIONS
global xhci_get_device_descriptor
global xhci_get_config_descriptor_9
global xhci_get_config_descriptor_full
global xhci_set_configuration
global xhci_parse_config
global device_desc_buffer
global config_desc_buffer
global xhci_configure_ep1_in
global xhci_submit_mouse_read
global mouse_data_buffer

; IMPORTATIONS
extern tr_enqueue
extern tr_init
extern ep0_mgr
extern current_slot_id
extern xhci_doorbell_base
extern device_init_state
extern xhci_input_context
extern xhci_send_configure_endpoint_cmd
extern xhci_output_context

; Données
section .bss
align 4096
xhci_ep1_in_ring:      resb 4096
align 64
device_desc_buffer: resb 64 ; Le buffer où le descripteur sera copié par le xHCI
config_desc_buffer: resb 256
align 8
ep1_in_mgr: resb tr_manager_t_size
align 8
mouse_data_buffer: resb 8


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

; Active le périphérique en sélectionnant la configuration 1
xhci_set_configuration:
    ; Setup Stage
    lea rdi, [rel ep0_mgr]

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
    call tr_enqueue

    ; Status Stage
    xor rax, rax
    xor r8d, r8d
    ; Control : Type = 4, DIR = 1 (IN), IOC = 1
    mov r9d, (4 << 10) | (1 << 16) | (1 << 5)
    call tr_enqueue

    ; Sonner le Doorbell
    mov rdx, qword [rel xhci_doorbell_base]
    mov ecx, dword [rel current_slot_id]
    mov dword [rdx + rcx * 4], 1

    mov dword [rel device_init_state], DEV_STATE_WAIT_SET_CONF
    PRINT_INLINE "[xHCI] Set Configuration envoyé !"

    ret

; Parcourt config_desc_buffer pour trouver l'Endpoint Interrupt IN
xhci_parse_config:
    lea rbx, [rel config_desc_buffer]


    ; Lire la longueur totale (wTotalLenght à l'offset 2)
    movzx rcx, word [rbx + 2]
    xor rdx, rdx

.parse_loop:
    cmp rdx, rcx
    jge .end_parsing

    movzx rax, byte [rbx + rdx]     ; AL = bLength
    test al, al
    jz .nothing   ; AntiBoucle

    cmp byte [rbx + rdx + 1], 0x05                    ; 5 = EndpointDescriptor
    je .found_endpoint

    add rdx, rax                    ; Sauter au descripteur suivant
    jmp .parse_loop

.found_endpoint:
    PRINT_INLINE "[xHCI] Endpoint Descriptor trouvé !"

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

.nothing:
    PRINT_INLINE "[xHCI] Obtenu un Descriptor de longueur 0"
    ret
.end_parsing:
    PRINT_INLINE "[xHCI] FIn de l'analyse de la configuration."
    ret


xhci_configure_ep1_in:
    ; Initialiser le Transfer Ring de l'EP1 IN
    lea rdi, [rel ep1_in_mgr]
    lea rsi, [rel xhci_ep1_in_ring]
    mov rdx, 256
    call tr_init

    ; Préparer le Input Context
;    lea rsi, [rel xhci_output_context]
;    lea rdi, [rel xhci_input_context]
;    add rdi, 0x20
;    mov rcx, 16
;.copy_context:
;    mov eax, dword [rsi]
;    mov dword [rdi], eax
;    add rsi, 4
;    add rdi, 4
;    loop .copy_context

    lea rbx, [rel xhci_input_context]

    ; Drop Context Flags = 0
    mov dword [rbx + 0x00], 0
    ; Add Context Flags = Bit 0 (Slot) | Bit 3 (EP1 IN)
    mov dword [rbx + 0x04], (1 << 0) | (1 << 3)

    ;Slot Context
    ; Le matériel exige que "Context Entries" idique le DCI le plus élevé actif
    ; On doit remplacer l'ancien '1' par '3' (Bits 27-31)
    mov eax, dword [rbx + 0x20]
    and eax, 0x07FFFFFF ; Effacer les anciens Context Entries
    or eax, (3 << 27)   ; Insérer 3
    mov dword [rbx + 0x20], eax

    ; EP1 IN Context (Offset 0x80)
    ; DWORD 1  : Error COutn (3), EP Type (7 = Interrupt IN), Max Packet (8)
    mov eax, (3 << 1) | (7 << 3) | (8 << 16)
    mov dword [rbx + 0x84], eax

    ; DWORD 2 & 3: TRDP (Pointeur Physique du Transfer RIng)
    mov rax, [rel ep1_in_mgr + tr_manager_t.base_phys]
    or rax, 1   ; Activer le bit DCS
    mov dword [rbx + 0x88], eax
    shr rax, 32
    mov dword [rbx + 0x8C], eax

    ; DWORD 4 : Average TRB Length (8) et Max ESIT Payload (8)
    ; Requis par le xHCI pour les Endpoints de type Interrupt
    mov eax, 8 | (8 << 16)
    mov dword [rbx + 0x90], eax

    ; Envoyer la commande au contrôleur
    call xhci_send_configure_endpoint_cmd

    ret

xhci_submit_mouse_read:
    lea rdi, [rel ep1_in_mgr]

    ; DWORD 0 & 1 Adresse physique du buffer
    lea rax, [rel mouse_data_buffer]
    VIRT_TO_PHYS rax

    ; DWORD 2 : Longueur du transfert (8 octets)
    mov r8d, 8

    ; DWORD 3 : TRB Type = 1 | IOC
    mov r9d, (1 << 10) | (1 << 5)

    call tr_enqueue

    ; Sonner le doorbell
    mov rdx, qword [rel xhci_doorbell_base]
    mov ecx, dword [rel current_slot_id]
    mov dword [rdx + rcx * 4], 3

    PRINT_INLINE "[xHCI] Demande de lecture envoyée à la souris !"
    ret