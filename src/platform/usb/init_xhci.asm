[BITS 64]
DEFAULT REL

%include "platform/serial.inc"

global init_xhci

extern xhci_bar0

section .rodata
    msg_reset_xhci_start:     db "[xHCI] Début du reset du xHCI ", 13, 10
    msg_reset_xhci_start_len  equ $ - msg_reset_xhci_start

    msg_reset_envoyee:        db "[xHCI] Reset envoyée au HCRST", 13, 10
    msg_reset_envoyee_len     equ $ - msg_reset_envoyee

    msg_reset_done:           db "[xHCI] Reset effectué, le xHCI est prêt à être configuré", 13, 10
    msg_reset_done_len        equ $ - msg_reset_done

section .text

init_xhci:

    push rbx
    push r12

    ; Charger l'adresse de BAR0
    mov r12, [rel xhci_bar0]
    test r12, r12
    jz .init_done

    PRINT_SERIAL msg_reset_xhci_start, msg_reset_xhci_start_len

    ; Trouver la base des registres opérationnels
    movzx eax, byte [r12]
    lea rbx, [r12 + rax]

    call reset_xhci



.init_done:
    pop r12
    pop rbx
    ret

    ; RBX = Operational Base
reset_xhci:
.wait_cnr_initial:
    ; Attendre que le bit CNR (bit 11 de USBSTS) = 0
    ; USBSTS est à l'offset 0x04 des registres opérationnels (32 bits)
    mov eax, dword [rbx + 0x04]
    test eax, 0x800
    jz .do_reset
    pause
    jmp .wait_cnr_initial

.do_reset:
    ; Déclencher le Host Controller Reset (HCRST)
    ; USBCMD est à l'offset 0x00 des registres opérationnels (32 bits)
    mov eax, dword [rbx + 0x00]
    or eax, 0x02
    mov dword [rbx + 0x00], eax

    PRINT_SERIAL msg_reset_envoyee, msg_reset_envoyee_len

.wait_reset_done:
    ; Attendre que le contrôleur remmete HCRST à 0
    mov eax, dword [rbx + 0x00]
    test eax, 0x02
    jz .wait_cnr_post_reset
    pause
    jmp .wait_reset_done

.wait_cnr_post_reset:
    ; Attendre que le contrôler signale à nouveau qu'il est prêt
    mov eax, dword [rbx + 0x04]
    test eax, 0x800
    jz .done_true
    pause
    jmp .wait_cnr_post_reset

.done_true:
    PRINT_SERIAL msg_reset_done, msg_reset_done_len

.done:
    ret

