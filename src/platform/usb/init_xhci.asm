[BITS 64]
DEFAULT REL

%include "platform/serial.inc"

global init_xhci

extern xhci_bar0
extern get_kernel_address_response

section .bss
align 64

xhci_dcbaa: resq 256

section .rodata
    msg_reset_xhci_start:     db "[xHCI] Début du reset du xHCI ", 13, 10
    msg_reset_xhci_start_len  equ $ - msg_reset_xhci_start

    msg_reset_envoyee:        db "[xHCI] Reset envoyée au HCRST", 13, 10
    msg_reset_envoyee_len     equ $ - msg_reset_envoyee

    msg_reset_done:           db "[xHCI] Reset effectué, le xHCI est prêt à être configuré", 13, 10
    msg_reset_done_len        equ $ - msg_reset_done

    msg_val_config:           db "[xHCI] Read-back CONFIG (MaxSlots) : "
    msg_val_config_len        equ $ - msg_val_config

    msg_val_dcbaap:           db "[xHCI] Read-back DCBAAP (Phys Addr): "
    msg_val_dcbaap_len        equ $ - msg_val_dcbaap

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

    ; Configurer le registre CONFIG (MaxSlotsEn)
    ; Lire HCSPARAMS1
    mov eax, dword [r12 + 0x04]
    and eax, 0xFF   ; masquer pour garder les bits 7:0

    ; Écrire cette valeur dans le registre CONFIG (offse 0x38 de Operationnal Base)
    mov dword [rbx +0x38], eax

    ; Configurer le pointeur DCBAAP
    ; DCBAAP est un registre 64 bits à offset 0x30 de Operational Base
    ; Adresse Physique
    lea rax, [rel xhci_dcbaa]
    mov rdi, [rel get_kernel_address_response]

    ;  adresse virtuel - base virtuel + base physique = adresse physique
    mov rcx, qword [rdi + 0x10]
    sub rax, rcx
    mov rdx, qword [rdi + 0x08]
    add rax, rdx

    mov qword [rbx + 0x30], rax

    PRINT_SERIAL msg_val_config, msg_val_config_len
    mov eax, dword [rbx + 0x38]
    PRINT_SERIAL_HEX rax

    PRINT_SERIAL msg_val_dcbaap, msg_val_dcbaap_len
    mov rax, qword [rbx + 0x30]
    PRINT_SERIAL_HEX rax

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

