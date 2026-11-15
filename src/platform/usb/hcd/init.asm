[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/memory.inc"
%include "platform/xhci.inc"

; -----------------------------------------
; EXPORTATIONS
; -----------------------------------------
; Méthodes publiques
global hcd_init
global hcd_start

; Variables publiques
global op_base
global runtime_base
global doorbell_base
global erst
global event_ring_mgr
global cmd_ring_mgr

; ----------------------------------------
; IMPORTATIONS
; ----------------------------------------
extern hcd_tr_init
extern hcd_er_init
extern core_usb_dcbaa

; ----------------------------------------------------
; DONNÉES GLOBALES
; ----------------------------------------------------
section .bss

alignb 8
; Bases MMIO
op_base:           resq 1
runtime_base:      resq 1
doorbell_base:     resq 1

; Command Ring
alignb 4096
cmd_ring:               resb 4096
alignb 8
cmd_ring_mgr:           resb tr_manager_t_size

; Event Ring
alignb 4096
event_ring:             resb 4096
alignb 8
event_ring_mgr:           resb er_manager_t_size

alignb 64
erst:                   resb 64

section .text
; =============================================================================
; INTERFACE PUBLIQUE
; =============================================================================

; -----------------------------------------------------------------------------
; hcd_start
; Rôle : Allume le contrôleur (Run) et active les interruptions globales (INTE)
; -----------------------------------------------------------------------------
hcd_start:
    mov rdx, [rel op_base]
    mov eax, dword [rdx + XHCI_USBCMD]
    or eax, (XHCI_CMD_RUN | XHCI_CMD_INTE)
    mov dword [rdx + XHCI_USBCMD], eax
    ret

; -----------------------------------------------------------------------------
; hcd_init
; Rôle : Point d'entrée principal. Initialise et configure le contrôleur matériel
; Paramètre : RDI = Adresse virutelle pointant sur la base MMIO du xHCI (BAR0)
; -----------------------------------------------------------------------------
hcd_init:
    push rbx
    push r12

    mov r12, rdi
    test r12, r12
    jz .init_done

    PRINT_INLINE "[xHCI] Début du reset du xHCI"

    ; Operational Base
    movzx eax, byte [r12 + XHCI_CAPLENGTH]
    lea rbx, [r12 + rax]
    mov qword [rel op_base], rbx

    ; Doorbell Base
    mov eax, dword [r12 + XHCI_DBOFF]
    and eax, 0xFFFFFFFC
    lea r9, [r12 + rax]
    mov qword [rel doorbell_base], r9

    ; Runtime Base
    mov eax, dword [r12 + XHCI_RTSOFF]
    and eax, 0xFFFFFFE0
    lea r8, [r12 + rax]
    mov qword [rel runtime_base], r8


    ; Reset du Contrôleur
    mov rdi, rbx
    call reset_controller
    test rax, rax
    jz .init_done

    ; Configuration Globale
    ; Configurer MaxSlots
    mov eax, dword [r12 + XHCI_HCSPARAMS1]
    and eax, 0xFF
    mov dword [rbx + XHCI_CONFIG], eax

    ; Enregistrer le tableau DCBAA
    lea rax, [rel core_usb_dcbaa]
    VIRT_TO_PHYS rax
    mov qword [rbx + XHCI_DCBAAP], rax

    ; Readback
    mov eax, dword [rbx + XHCI_CONFIG]
    LOG_HEX "[xHCI] Read-back CONFIG (MaxSlots) : ", rax
    mov rax, qword [rbx + XHCI_DCBAAP]
    LOG_HEX "[xHCI] Read-back DCBAAP (Phys Addr): ", rax

    ; Initialisation des Anneaux de base
    call setup_command_ring
    call setup_event_ring

.init_done:
    pop r12
    pop rbx
    ret

; =============================================================================
; FONCTIONS INTERNES
; =============================================================================

; -----------------------------------------------------------------------------
; reset_controller
; Paramètre : RDI = op_base
; -----------------------------------------------------------------------------
reset_controller:
    mov rcx, RESET_TIMEOUT      ; Initialiser le compteur de sécurité

.wait_cnr_initial:
    mov eax, dword [rdi + XHCI_USBSTS]
    test eax, XHCI_STS_CNR  ; Vérifier si Controller Not Ready
    jz .do_reset            ; Si prêt, on déclenche le reset
    pause
    dec rcx
    jnz .wait_cnr_initial
    jmp .fail

.do_reset:
    ; Envoyer le signal de Reset
    mov eax, dword [rdi + XHCI_USBCMD]
    or eax, XHCI_CMD_HCRST
    mov dword [rdi + XHCI_USBCMD], eax
    PRINT_INLINE "[xHCI] Reset envoyée au HCRST"
    mov rcx, RESET_TIMEOUT      ; Réinitialiser le timeout

.wait_reset_done:
    ; Attendre que le contrôleur remmete HCRST à 0
    mov eax, dword [rdi + XHCI_USBCMD]
    test eax, XHCI_CMD_HCRST
    jz .wait_cnr_post_reset
    pause
    dec rcx
    jnz .wait_reset_done
    jmp .fail

.wait_cnr_post_reset:
    mov rcx, RESET_TIMEOUT

.wait_cnr_post_loop:
    mov eax, dword [rdi + XHCI_USBSTS]
    test eax, XHCI_STS_CNR
    jz .success
    pause
    dec rcx
    jmp .wait_cnr_post_loop
    jmp .fail

.success:
    PRINT_INLINE "[xHCI] Reset effectué, le xHCI est prêt à être configuré"
    mov rax, 1
    ret

.fail:
    xor rax, rax
    ret

; -----------------------------------------------------------------------------
; setup_command_ring
; -----------------------------------------------------------------------------
setup_command_ring:
    lea rdi, [rel cmd_ring_mgr]
    lea rsi, [rel cmd_ring]
    mov rdx, 256
    call hcd_tr_init

    ; Inscrire le Command Ring dans le registre CRCR
    mov rcx, [rel cmd_ring_mgr + tr_manager_t.base_phys]
    or rcx, XHCI_CRCR_RCS                    ; Bit 0 (RCS - Ring Cycle State) = 1

    mov r8, qword [rel op_base]    ; Lire la base opérationnelle
    mov qword [r8 + XHCI_CRCR], rcx          ; CRCR est à l'offset 0x18

    ; Readback
    mov rax, qword [r8 + XHCI_CRCR]
    LOG_HEX "[xHCI] Read-back CRCR : ", rax
    ret


; -----------------------------------------------------------------------------
; setup_event_ring
; -----------------------------------------------------------------------------
setup_event_ring:
    ; Initialiser la structure logicielle
    lea rdi, [rel event_ring_mgr]
    lea rsi, [rel event_ring]
    mov rdx, 256        ; Capacité : 256 TRBs
    call hcd_er_init        ; Calcul base_phys et initialise le cycle à 1

    ; Configure la table ERST (Event Ring Segment Table)
    lea r9, [rel erst]
    mov r10, [rel event_ring_mgr + er_manager_t.base_phys]

    mov qword [r9 + 0], r10             ; Adresse pgysique du segment
    mov dword [r9 + 8], 256             ; Taille (256 TRBs)
    mov dword [r9 + 12], 0              ; Réservé

    ; Obtenir l'adresse physique de l'ERST
    mov r11, r9
    VIRT_TO_PHYS r11

    ; Configurer les registres de l'Interrupter 0
    mov r8, qword [rel runtime_base]
    lea r8, [r8 + XHCI_IR0_BASE]                 ; R8 = Base de l'Interrupter 0

    mov dword [r8 + XHCI_ERSTSZ], 1            ; ERSTSZ (1 segment)
    mov qword [r8 + XHCI_ERSTBA], r11          ; ERSTBA (Base de l'ERST)
    mov r10, [rel event_ring_mgr + er_manager_t.dequeue_phys]
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