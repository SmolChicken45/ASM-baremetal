[BITS 64]
DEFAULT REL

%include "platform/serial.inc"

global init_xhci
global xhci_runtime_base
global xhci_event_ring_phys
global xhci_event_ring

extern xhci_bar0
extern get_kernel_address_response

section .bss
align 64

xhci_dcbaa: resq 256
align 4096 ; Pour être aligné sur une page entière
xhci_cmd_ring: resb 4096
align 4096
xhci_event_ring: resb 4096
align 64
xhci_erst: resb 64
align 8
xhci_event_ring_phys: resq 1
xhci_runtime_base: resq 1


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

    msg_val_crcr:             db "[xHCI] Read-back CRCR : "
    msg_val_crcr_len          equ $ - msg_val_crcr

    msg_val_erdp:             db "[xHCI] Read-back ERDP : "
    msg_val_erdp_len          equ $ - msg_val_erdp

    msg_val_erstba:           db "[xHCI] Read-back ERSTBA : "
    msg_val_erstba_len        equ $ - msg_val_erstba

    msg_xhci_running:         db "[xHCI] Le controleur est en mode RUN !", 13, 10
    msg_xhci_running_len      equ $ - msg_xhci_running

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

    ; CONFIG DU COMMAND ING (CRCR)
    lea rax, [rel xhci_cmd_ring]
    mov rdi, [rel get_kernel_address_response]

    mov rcx, qword [rdi + 0x10]
    sub rax, rcx
    mov rdx, qword [rdi + 0x08]
    add rax, rdx        ; RAX = adresse Physique du Command Ring

    lea rdi, [rel xhci_cmd_ring]
    mov qword [rdi + 4080], rax

    mov dword [rdi + 4088], 0
    ; Les 4 derniers octets (offset 12) contiennent le Type et les Flags.
    ; TRB Type = 6 (Link TRB) -> on décale de 10 bits: (6 << 10) = 0x1800
    ; Bit Toggle Cycle (TC) = bit 1 (0x02) : Indique au matériel que le cycle bascule ici.
    mov dword [rdi + 4092], 0x1802

    mov rcx, rax
    or rcx, 1
    mov qword [rbx + 0x18], rcx

    PRINT_SERIAL msg_val_crcr, msg_val_crcr_len
    mov rax, qword [rbx + 0x18]
    PRINT_SERIAL_HEX rax

    ; Allocation de l'event ring et de l'ERST
    mov eax, dword [r12 + 0x18]     ; Lire RTSOFF
    and eax, 0xFFFFFFE0
    lea r8, [r12 + rax]             ; R8 = Base des runtime registers

    mov qword [rel xhci_runtime_base], r8

    lea r8, [r8 + 0x20]             ; R8 = Base de l'Interrupter 0

    lea rax, [rel xhci_event_ring]
    mov rdi, [rel get_kernel_address_response]
    mov rcx, qword [rdi + 0x10]
    sub rax, rcx
    mov rdx, qword [rdi + 0x08]
    add rax, rdx                    ; RAX = adresse physique de l'Event ring
    mov r14, rax
    mov qword [rel xhci_event_ring_phys], rax

    lea rdi, [rel xhci_erst]

    ; Une entrée ERST = 16 octets :
    ; [0..7]  : Adresse Physique du Segment (R14)
    ; [8..11] : Taille du segment en nombre de TRB (256)
    ; [12..15]: Réservé (0)
    mov qword [rdi + 0], r14
    mov dword [rdi + 8], 256
    mov dword [rdi + 12], 0

    lea rax, [rel xhci_erst]
    mov rdi, [rel get_kernel_address_response]
    mov rcx, qword [rdi + 0x10]
    sub rax, rcx
    mov rdx, qword [rdi + 0x08]
    add rax, rdx                    ; rax = adresse physique de l'ERST
    mov r15, rax


    ; Configurer les registres de l'Interrupter 0

    ; ERSTSZ
    mov dword [r8 + 0x08], 1
    ; ERDP
    mov qword [r8 + 0x18], r14
    ; ERSTBA
    mov qword [r8 + 0x10], r15

    PRINT_SERIAL msg_val_erdp, msg_val_erdp_len
    mov rax, qword [r8 + 0x18]
    PRINT_SERIAL_HEX rax

    PRINT_SERIAL msg_val_erstba, msg_val_erstba_len
    mov rax, qword [r8 + 0x10]
    PRINT_SERIAL_HEX rax

    ; Allumer le controleur
    ; bit Run/Stop (bit 0 de USBCMD)
    ; USBCMD est à offset 0x00 de Operational Base (RBX)
    mov eax, dword [rbx + 0x00]
    or eax, 0x01
    mov dword [rbx + 0x00], eax

.wait_running:
    ; bit HCH (Halted) (bit 0 de USBSTS)
    ; USBSTS est à offset 0x04 de Operational Base
    mov eax, dword [rbx + 0x04]
    test eax, 0x01
    jnz .wait_running

    PRINT_SERIAL msg_xhci_running, msg_xhci_running_len


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

