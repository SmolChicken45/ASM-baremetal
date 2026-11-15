[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/memory.inc"
%include "platform/xhci.inc"

; =======================================================================
; EXPORTATIONS
; =======================================================================
global hcd_event_handler


global current_slot_id

; =======================================================================
; IMPORTATIONS
; =======================================================================
extern runtime_base
extern event_ring_mgr
extern hcd_er_dequeue

; Interfaces de la couche core
extern core_usb_handle_port_change
extern core_usb_handle_cmd_completion
extern core_usb_handle_transfer_completion

section .text

; =======================================================================
; hcd_event_handler
; Routine d'Interruption (ISR) globale du contrôleur xHCI
; Dépile les événements de l'Event Ring et les route vers la couche Core.
; =======================================================================
hcd_event_handler:
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

    xor r14, r14    ; R14 gardera la trace de la dernière adresse ERDP écrite

.process_next_event:

    ; Demander le prochain événement au gestionnaire
    lea rdi, [rel event_ring_mgr]
    call hcd_er_dequeue

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

    PRINT_INLINE "[xHCI HCD] Évenement inconnu détecté !"
    jmp .process_next_event
; ----------------------------------------------------------------
; Gestion : Port Status Change (Hotplug)
; ----------------------------------------------------------------
.is_port_change:
    ; Extraire le Port ID depuis le DWORD 0
    mov eax, dword [rbx + TRB_EVENT_DATA]
    shr eax, TRB_EVENT_PORT_SHIFT

    ; RDI = Port ID
    mov rdi, rax
    call core_usb_handle_port_change

    jmp .process_next_event

; ----------------------------------------------------------------
; Gestion : Command Completion
; ----------------------------------------------------------------
.is_cmd_completion:
    ; Extraire le Completion Code
    mov ecx, dword [rbx + TRB_EVENT_STATUS]
    shr ecx, TRB_COMPL_CODE_SHIFT

    cmp ecx, COMPL_SUCCESS
    jne .cmd_failed

    ; Extraire le Slot ID renvoyé
    mov r8d, dword [rbx + TRB_EVENT_CTRL]
    shr r8d, TRB_EVENT_SLOT_SHIFT

    ; RDI = Completion Code, RSI = Slot ID
    mov rdi, rcx
    mov rsi, r8
    call core_usb_handle_cmd_completion

    jmp .process_next_event

.cmd_failed:
    PRINT_INLINE "[xHCI HCD] Erreur : Commande terminée avec une faute !"
    jmp .process_next_event

.is_transfer_event:
    ; Vérifier que le transfert a réussi
    mov ecx, dword [rbx + TRB_EVENT_STATUS]
    shr ecx, TRB_COMPL_CODE_SHIFT

    cmp ecx, COMPL_SUCCESS
    je .transfer_success

    cmp ecx, 0x0D
    je .transfer_success

    PRINT_INLINE "[xHCI] Commande terminée avec une faute"
    jmp .process_next_event


.transfer_success:
    ; RDI = COmpletion Code
    ; RSI = Pointeur physique du TRB qui a déclenché l'event
    mov rdi, rcx
    mov rsi, qword [rbx + TRB_DWORD0]
    call core_usb_handle_transfer_completion

    jmp .process_next_event

; ----------------------------------------------------------------
; Fin de l'interruption : Mise à jour de l'ERDP et de l'APIC
; ----------------------------------------------------------------
.no_more_events:
    ; R14 contient l'adresse physique renvoyé par le dernier appel réussi à er_dequeue
    ; Si R14 est à 0, on doit récuperer l'adresse actuelle
    test r14, r14
    jnz .update_erdp

    ; Si l'interruption a été déclenchée mais qu'il n'y avait rien
    ; on relit simplement le pointeur physique actuel depuis le manager
    lea rdi, [rel event_ring_mgr]
    mov r14, [rdi + er_manager_t.dequeue_phys]


.update_erdp:
    ; Écrire le pointeur de retour dans le matériel
    mov r13, qword [rel runtime_base]

    or r14, (1 << 3)   ; Activer le bit EHB (Event Handler Busy)

    mov qword [r13 + XHCI_IR0_BASE + XHCI_ERDP], r14

    ; Avertir le Local APIC
    ; TODO Rendre le APIC dynamique
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