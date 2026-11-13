[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/memory.inc"
%include "platform/xhci.inc"

; -----------------------------------------------
; EXPORTATIONS
; -----------------------------------------------
; Méthodes
global init_xhci_command_ring
global init_xhci_event_ring

; Variables
global xhci_cmd_ring
global xhci_event_ring
global xhci_erst
global command_ring_index
global command_cycle_state
global xhci_event_ring_phys

; ----------------------------------------------
; IMPORTATIONS
; ----------------------------------------------
extern xhci_op_base
extern xhci_runtime_base

; ----------------------------------------------
; DONNÉES ET STRUCTURES DES RINGS
; ----------------------------------------------
section .data
    command_cycle_state: db 1

section .bss
align 4096
xhci_cmd_ring:      resb 4096

align 4096
xhci_event_ring:    resb 4096

align 64
xhci_erst:          resb 64

command_ring_index: resq 1

align 8
xhci_event_ring_phys:   resq 1

section .text

; ===================================================================
; FONCTION : init_xhci_command_ring
; Rôle : ALloue et configure le COmmand Ring (CRCR) et son Link TRB
; ===================================================================
init_xhci_command_ring:
    ; Obtenir l'adresse physique
    lea rdx, [rel xhci_cmd_ring]
    mov rax, rdx
    VIRT_TO_PHYS rax

    ; Configurer le Link TRB à la fin du Ring (Index 255 -> offset 4080)
    mov qword [rdx + 4080 + TRB_DWORD0], rax         ; Pointeur de retour au début du ring
    mov dword [rdx + 4080 + TRB_DWORD2], 0
    ; Type 6 (Link TRB) | TC = 1
    mov r9d, (TRB_TYPE_LINK << TRB_TYPE_SHIFT) | TRB_TC_BIT
    mov dword [rdx + 4080 + TRB_DWORD3], r9d

    ; Inscrire le Command Ring dans le registre CRCR
    mov rcx, rax
    or rcx, XHCI_CRCR_RCS                           ; Bit 0 (RCS - Ring Cycle State) = 1

    mov r8, qword [rel xhci_op_base]    ; Lire la base opérationnelle
    mov qword [r8 + XHCI_CRCR], rcx          ; CRCR est à l'offset 0x18

    ; Readback
    mov rax, qword [r8 + XHCI_CRCR]
    LOG_HEX "[xHCI] Read-back CRCR : ", rax

    ; Initialiser les variables de suivi
    mov qword [rel command_ring_index], 0
    mov byte [rel command_cycle_state], 1

    ret

; ==========================================================================
; FONCTION : init_xhci_event_ring
; Rôle : Alloue et configure l'Event Ring, l'ERST, et l'Interrupter 0
; ==========================================================================
init_xhci_event_ring:
    ; ; Obtenir l'adresse physique de l'Event Ring
    lea rdx, [rel xhci_event_ring]
    mov rax, rdx
    VIRT_TO_PHYS rax
    mov qword [rel xhci_event_ring_phys], rax
    mov r10, rax

    ; Configure la table ERST (Event Ring Segment Table)
    lea r9, [rel xhci_erst]
    mov qword [r9 + 0], r10             ; Adresse pgysique du segment
    mov dword [r9 + 8], 256             ; Taille (256 TRBs)
    mov dword [r9 + 12], 0              ; Réservé

    ; Obtenir l'adresse physique de l'ERST
    mov r11, r9
    VIRT_TO_PHYS r11

    ; Configurer les registres de l'Interrupter 0
    mov r8, qword [rel xhci_runtime_base]
    lea r8, [r8 + XHCI_IR0_BASE]                 ; R8 = Base de l'Interrupter 0

    mov dword [r8 + XHCI_ERSTSZ], 1            ; ERSTSZ (1 segment)
    mov qword [r8 + XHCI_ERDP], r10          ; ERDP (Dequeue Pointer)
    mov qword [r8 + XHCI_ERSTBA], r11          ; ERSTBA (Base de l'ERST)

    ; Readback
    mov rax, qword [r8 + XHCI_ERDP]
    LOG_HEX "[xHCI] Read-back ERDP : ", rax

    mov rax, qword [r8 + XHCI_ERSTBA]
    LOG_HEX "[xHCI] Read-back ERSTBA : ", rax

    ; Activer les interruptions pour cet interrupter (IMAN & IMOD)
    mov eax, dword [r8 + XHCI_IMAN]
    or eax, (XHCI_IMAN_IP | XHCI_IMAN_IE)    ; Bit 0 (Clear) | Bit 1 (Enable)
    mov dword [r8 + XHCI_IMAN], eax

    mov dword [r8 + XHCI_IMOD], 4000         ; IMOD (~1ms)

    ret