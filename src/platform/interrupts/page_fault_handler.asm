[BITS 64]
DEFAULT REL

%include "platform/serial.inc"

global page_fault_handler

section .text

; Handler pour l'interruption 14
page_fault_handler:
    ; Le CPU vient de pousser sur la pile, dans cet ordre:
    ; [RSP + 0]     : Error Code
    ; [RSP + 8]     : RIP (instruction exacte qui a crashé)
    ; [RSP + 16]    : CS
    ; [RSP + 24]    : RFLAGS
    ; [RSP + 32]    : Ancien RSP

    PRINT_INLINE "!!! KERNEL PANIC : PAGE FAULT !!!"

    ; Récupérer et afficher l'adresse mémoire fautive (CR2)
    mov rax, cr2
    LOG_HEX "CR2 (Adresse mémoire refusée) : ", rax

    ; Récupérer et afficher le RIP (L'instruction qui a planté)
    mov rax, [rsp + 8]
    LOG_HEX "RIP (lieu exact du crash) : ", rax

    cli
.halt:
    hlt
    jmp .halt