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



section .data

    event_ccs:              db 1

section .bss
    event_ring_index:       resq 1
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

.process_next_event:
    ; TRB actuel
    lea rbx, [rel xhci_event_ring]
    mov r12, qword [rel event_ring_index]
    add rbx, r12

    mov eax, dword [rbx + TRB_EVENT_CTRL]
    LOG_HEX "Valeur brute TRB_EVENT_CTRL lue : ", rax
    ; Vérifier le Cycle Bit (bit 0)
    mov cl, byte [rel event_ccs]
    mov edx, eax
    and edx, 1
    cmp dl, cl
    jne .no_more_events

    ; Isoler le type de TRB
    mov edx, eax
    shr edx, TRB_TYPE_SHIFT
    and edx, 0x3F

    cmp edx, TRB_TYPE_PORT_STAT
    je .is_port_change

    cmp edx, TRB_TYPE_CMD_COMPL
    je .is_cmd_completion

    PRINT_INLINE "[xHCI] Nouvel evenement detecte !"
    jmp .continue_event

.is_port_change:

    ; PRINT_INLINE "[xHCI] HOTPLUG : Port Status Change Event recu !"
    ; PRINT_INLINE "[xHCI] -> Sur le Port ID : "

    mov eax, dword [rbx + TRB_EVENT_DATA]
    shr eax, TRB_EVENT_PORT_SHIFT

    call xhci_handle_port_change

    jmp .continue_event

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

    jmp .continue_event

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

    jmp .continue_event

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

    jmp .continue_event

.cmd_failed:
    PRINT_INLINE "[xHCI] Commande terminée avec une faute"

.continue_event:

    add r12, 16
    cmp r12, 4096
    jl .save_index

    xor r12, r12
    xor byte [rel event_ccs], 1

.save_index:
    mov qword [rel event_ring_index], r12
    jmp .process_next_event

.no_more_events:

    mov r13, qword [rel xhci_runtime_base]
    mov rax, qword [rel xhci_event_ring_phys]
    add rax, r12

    or rax, 8   ; Activer le bit EHB (Event Handler Busy)

    mov qword [r13 + XHCI_IR0_BASE + XHCI_ERDP], rax

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