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
global xhci_erst
global xhci_event_ring_mgr
global xhci_cmd_ring_mgr

; ----------------------------------------------
; IMPORTATIONS
; ----------------------------------------------
extern xhci_op_base
extern xhci_runtime_base
extern tr_init
extern er_init

; ----------------------------------------------
; DONNÉES ET STRUCTURES DES RINGS
; ----------------------------------------------


section .bss
align 4096
xhci_cmd_ring:      resb 4096

align 4096
xhci_event_ring:    resb 4096

align 64
xhci_erst:          resb 64

align 8
xhci_event_ring_phys:   resq 1
align 8
xhci_cmd_ring_mgr: resb tr_manager_t_size
align 8
xhci_event_ring_mgr: resb er_manager_t_size

section .text

; ===================================================================
; FONCTION : init_xhci_command_ring
; Rôle : ALloue et configure le COmmand Ring (CRCR) et son Link TRB
; ===================================================================
init_xhci_command_ring:
    ; Initialiser la structure logicielle
    lea rdi, [rel xhci_cmd_ring_mgr]
    lea rsi, [rel xhci_cmd_ring]
    mov rdx, 256
    call tr_init

    ; Inscrire le Command Ring dans le registre CRCR
    mov rcx, [rel xhci_cmd_ring_mgr + tr_manager_t.base_phys]
    or rcx, XHCI_CRCR_RCS                    ; Bit 0 (RCS - Ring Cycle State) = 1

    mov r8, qword [rel xhci_op_base]    ; Lire la base opérationnelle
    mov qword [r8 + XHCI_CRCR], rcx          ; CRCR est à l'offset 0x18

    ; Readback
    mov rax, qword [r8 + XHCI_CRCR]
    LOG_HEX "[xHCI] Read-back CRCR : ", rax
    ret

; ==========================================================================
; FONCTION : init_xhci_event_ring
; Rôle : Alloue et configure l'Event Ring, l'ERST, et l'Interrupter 0
; ==========================================================================
init_xhci_event_ring:
    ; Initialiser la structure logicielle
    lea rdi, [rel xhci_event_ring_mgr]
    lea rsi, [rel xhci_event_ring]
    mov rdx, 256        ; Capacité : 256 TRBs
    call er_init        ; Calcul base_phys et initialise le cycle à 1

    ; Configure la table ERST (Event Ring Segment Table)
    lea r9, [rel xhci_erst]

    ; On récupère l'adresse physique calculée par er_init
    mov r10, [rel xhci_event_ring_mgr + er_manager_t.base_phys]

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
    mov qword [r8 + XHCI_ERSTBA], r11          ; ERSTBA (Base de l'ERST)
    mov r10, [rel xhci_event_ring_mgr + er_manager_t.dequeue_phys]
    mov qword [r8 + XHCI_ERDP], r10          ; ERDP (Dequeue Pointer)

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