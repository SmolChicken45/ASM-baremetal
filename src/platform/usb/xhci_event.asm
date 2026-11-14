[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/memory.inc"
%include "platform/xhci.inc"

global xhci_event_handler
global current_slot_id

extern xhci_event_ring
extern xhci_event_ring_phys
extern xhci_runtime_base
extern xhci_handle_port_change
extern xhci_setup_device_context
extern xhci_output_context
extern xhci_dcbaa
extern xhci_send_address_device_cmd
extern device_init_state
extern er_dequeue
extern xhci_event_ring_mgr
extern device_desc_buffer
extern xhci_get_device_descriptor
extern config_desc_buffer
extern xhci_get_config_descriptor_9
extern xhci_get_config_descriptor_full
extern xhci_set_configuration
extern xhci_parse_config

section .bss
    current_slot_id:        resd 1

section .text

xhci_event_handler:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    xor r14, r14
.process_next_event:

    ; Demander le prochain événement au gestionnaire
    lea rdi, [rel xhci_event_ring_mgr]
    call er_dequeue

    test rax, rax
    jz .no_more_events

    ; Suavegarder la nouvelle adresse physique pour l'ERDP
    mov r14, rdx

    ; RAX pointe vers le TRB de l'événement
    mov rbx, rax

    ; mov eax, dword [rbx + TRB_DWORD3]
    ; LOG_HEX "[xHCI] Event TRB Dword 3 (Type/Cycle) : ", rax

    ; mov eax, dword [rbx + TRB_DWORD2]
    ; LOG_HEX "[xHCI] Event TRB Dword 2 (Status/Compl): ", rax

    mov eax, dword [rbx + TRB_EVENT_CTRL]
    ; LOG_HEX "Valeur brute TRB_EVENT_CTRL lue : ", rax


    ; Isoler le type de TRB
    mov edx, eax
    shr edx, TRB_TYPE_SHIFT
    and edx, 0x3F

    cmp edx, TRB_TYPE_PORT_STAT
    je .is_port_change

    cmp edx, TRB_TYPE_CMD_COMPL
    je .is_cmd_completion

    cmp edx, TRB_TYPE_TRANSFER_EVENT
    je .is_transfer_event

    PRINT_INLINE "[xHCI] Nouvel evenement detecte !"
    jmp .process_next_event

.is_port_change:

    ; PRINT_INLINE "[xHCI] HOTPLUG : Port Status Change Event recu !"
    ; PRINT_INLINE "[xHCI] -> Sur le Port ID : "

    mov eax, dword [rbx + TRB_EVENT_DATA]
    shr eax, TRB_EVENT_PORT_SHIFT

    call xhci_handle_port_change

    jmp .process_next_event

.is_cmd_completion:

    mov ecx, dword [rbx + TRB_EVENT_STATUS]
    shr ecx, TRB_COMPL_CODE_SHIFT
    cmp ecx, COMPL_SUCCESS
    jne .cmd_failed

    mov eax, dword [rel device_init_state]
    cmp eax, DEV_STATE_WAIT_SLOT
    je .handle_enable_slot_success

    cmp eax, DEV_STATE_WAIT_ADDR
    je .handle_address_device_success

    jmp .process_next_event

.handle_enable_slot_success:
    mov ecx, dword [rbx + TRB_EVENT_CTRL]   ; Lire le dword 3
    shr ecx, TRB_EVENT_SLOT_SHIFT                 ; Isoler le Slot ID (24-31)

    mov dword [rel current_slot_id], ecx

    LOG_HEX "[xHCI] Commande terminée avec succès ! Slot ID obtenu : ", rcx

    ; Création des context
    call xhci_setup_device_context

    ; output_context en adresse Physique
    lea rax, [rel xhci_output_context]
    VIRT_TO_PHYS rax

    lea rbx, qword [rel xhci_dcbaa]
    mov ecx, dword [rel current_slot_id]
    mov qword [rbx + rcx * 8], rax

    call xhci_send_address_device_cmd

    jmp .process_next_event

.handle_address_device_success:

    ; La commande a réussi, l'adresse USB a été attirbuée par le matéiel
    ; Le xHCI a écrit cette adresse dans le Slot Context de l'OUTPUT Context
    ; Le Slot COntext commence à l'offset 0x00 de l'Output COntext
    ; L'adresse USB est dans le DWORD 3
    lea rbx, [rel xhci_output_context]
    mov eax, dword [rbx + 0x0C]
    and eax, 0xFF

    LOG_HEX "[xHCI] Address device réussi !, Adresse USB : ", rax

    mov dword [rel device_init_state], DEV_STATE_IDLE

    call xhci_get_device_descriptor

    jmp .process_next_event
.is_transfer_event:
    ; Vérifier que le transfert a réussi
    mov ecx, dword [rbx + TRB_EVENT_STATUS]
    shr ecx, TRB_COMPL_CODE_SHIFT
    cmp ecx, COMPL_SUCCESS
    jne .transfer_failed

    ; Vérifier si on attendait le Device Descriptor
    mov eax, dword [rel device_init_state]

    cmp eax, DEV_STATE_WAIT_DESC
    je .handle_device_desc_success

    cmp eax, DEV_STATE_WAIT_CONF9
    je .handle_conf9_success

    cmp eax, DEV_STATE_WAIT_CONF_FULL
    je .handle_conf_full_success

    cmp eax, DEV_STATE_WAIT_SET_CONF
    je .handle_set_conf_success

    PRINT_INLINE "[xHCI] Transfère Non-géré est détecté"
    jmp .process_next_event

.handle_device_desc_success:
    PRINT_INLINE "[xHCI] Descripteur de périphérique lu avec succès !"

    ; Charger l'adresse du buffer où le xHCI a écrit la réponse
    lea rbx, [rel device_desc_buffer]

    ; Vendor ID (2 bytes -> Offset 8)
    movzx eax, word [rbx + 8]
    LOG_HEX "Vendor ID : ", rax

    ; Product ID (2 bytes -> offset 10)
    movzx eax, word [rbx + 10]
    LOG_HEX "Product ID : ", rax

    ; Lire le Max Packet Size (offset 7)
    movzx eax, byte [rbx + 7]
    LOG_HEX "Max Packet Size : ", rax

    mov dword [rel device_init_state], DEV_STATE_IDLE

    call xhci_get_config_descriptor_9

    jmp .process_next_event

.handle_conf9_success:
    PRINT_INLINE "[xHCI] En-tête de configuration lu !"

    lea rbx, [rel config_desc_buffer]

    ; Le wTotalLength est sur 2 octets à l'offset 2
    movzx eax, word [rbx + 2]
    LOG_HEX "wTotalLength trouvé : ", rax

    mov dword [rel device_init_state], DEV_STATE_IDLE
    mov r10, rax
    call xhci_get_config_descriptor_full

    jmp .process_next_event

.handle_conf_full_success:
    PRINT_INLINE "[xHCI] Arbre de configuration COMPLET lu en RAM !"

    mov dword [rel device_init_state], DEV_STATE_IDLE
    call xhci_set_configuration

    jmp .process_next_event

.handle_set_conf_success:
    PRINT_INLINE "[xHCI] SET CONFIGURATION réussi ! Périphérique ACTIF"

    call xhci_parse_config

    mov dword [rel device_init_state], DEV_STATE_IDLE
    jmp .process_next_event

.transfer_failed:
    PRINT_INLINE "[xHCI] Erreur lors d'un transfert USB !"
    jmp .process_next_event

.cmd_failed:
    PRINT_INLINE "[xHCI] Commande terminée avec une faute"
    jmp .process_next_event

.no_more_events:
    ; R14 contient l'adresse physique renvoyé par le dernier appel réussi à er_dequeue
    ; Si R14 est à 0, on doit récuperer l'adresse actuelle
    test r14, r14
    jnz .update_erdp

    ; Si l'interruption a été déclenchée mais qu'il n'y avait rien
    ; on relit simplement le pointeur physique actuel depuis le manager
    lea rdi, [rel xhci_event_ring_mgr]
    mov r14, [rdi + er_manager_t.dequeue_phys]


.update_erdp:
    ; Écrire le pointeur de retour dans le matériel
    mov r13, qword [rel xhci_runtime_base]

    or r14, (1 << 3)   ; Activer le bit EHB (Event Handler Busy)

    mov qword [r13 + XHCI_IR0_BASE + XHCI_ERDP], r14

    mov rbx, 0xFFFF8000FEE000B0
    mov eax, 0
    mov dword [rbx], eax

    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    iretq