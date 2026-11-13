[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/memory.inc"
%include "platform/xhci.inc"

; CONSTANTES PCI LOCALES
%define PCI_COMMAND_REG     0x04
%define PCI_CMD_BUS_MASTER  (1 << 2)
; -----------------------------------------
; EXPORTATIONS
; -----------------------------------------
; Méthodes publiques
global init_xhci
global start_xhci_run
global pci_xhci_enable_msi

; Variables publiques
global xhci_op_base
global xhci_runtime_base
global xhci_doorbell_base

; ----------------------------------------
; IMPORTATIONS
; ----------------------------------------

extern xhci_bar0
extern xhci_dcbaa

extern init_xhci_command_ring
extern init_xhci_event_ring


; Reste à clairer peut à peut
extern pci_enable_msi
extern xhci_bus
extern xhci_dev
extern xhci_func
extern pci_read_dword
extern pci_write_dword

; ----------------------------------------------------
; DONNÉES GLOBALES
; ----------------------------------------------------
section .bss

align 8
xhci_op_base: resq 1
xhci_runtime_base: resq 1
xhci_doorbell_base: resq 1

section .text

; =============================================================================
; FONCTION : pci_xhci_enable_msi
; =============================================================================
pci_xhci_enable_msi:
    mov cl, byte [xhci_bus]
    mov dl, byte [xhci_dev]
    mov r8b, byte [xhci_func]
    mov r10d, 0x22
    call pci_enable_msi
    ret
; =============================================================================
; FONCTION : start_xhci_run
; Rôle : Allume le contrôleur (Run) et active les interruptions globales (INTE)
; =============================================================================
start_xhci_run:
    mov rdx, [rel xhci_op_base]
    mov eax, dword [rdx + XHCI_USBCMD]
    or eax, (XHCI_CMD_RUN | XHCI_CMD_INTE)
    mov dword [rdx + XHCI_USBCMD], eax
    ret

; =============================================================================
; FONCTION : init_xhci
; Rôle : Séquence principale d"initialisation du contrôleur matériel
; =============================================================================
init_xhci:

    push rbx
    push r12

    ; Forcer l'activation du bus master
    mov cl, byte [xhci_bus]
    mov dl, byte [xhci_dev]
    mov r8b, byte [xhci_func]
    mov r9b, PCI_COMMAND_REG
    call pci_read_dword

    or eax, PCI_CMD_BUS_MASTER

    mov cl, byte [xhci_bus]
    mov dl, byte [xhci_dev]
    mov r8b, byte [xhci_func]
    mov r9b, PCI_COMMAND_REG
    call pci_write_dword


    ; ---------------------------------------------------------------
    ; Localisation des bases matérielles (Cap, Op, Runtime, Doorbell)
    ; ---------------------------------------------------------------
    mov r12, [rel xhci_bar0]    ; R12 = Capability Base (BAR0 mappé)
    test r12, r12
    jz .init_done

    PRINT_INLINE "[xHCI] Début du reset du xHCI"

    ; Calcul de l'Operational Base
    movzx eax, byte [r12 + XHCI_CAPLENGTH]
    lea rbx, [r12 + rax]
    mov qword [rel xhci_op_base], rbx

    ; Calcul du Doorbell Base
    mov eax, dword [r12 + XHCI_DBOFF] ; DBOFF
    and eax, 0xFFFFFFFC
    lea r9, [r12 + rax]
    mov qword [rel xhci_doorbell_base], r9

    ; Calcul du Runtime Base
    mov eax, dword [r12 + XHCI_RTSOFF] ; RTSOFF
    and eax, 0xFFFFFFE0
    lea r8, [r12 + rax]
    mov qword [rel xhci_runtime_base], r8

    ; -----------------------------------------------------------------
    ; Reset du Contrôleur
    ; -----------------------------------------------------------------
    mov rdi, rbx
    call reset_xhci

    test rax, rax
    jz .init_done

    ; -----------------------------------------------------------------
    ; Configuration Globale (CONFIG et DCBAAP)
    ; -----------------------------------------------------------------

    ; Configurer MaxSlots (Lire HCSPARAMS1, copier dans CONFIG)
    mov eax, dword [r12 + XHCI_HCSPARAMS1]
    and eax, 0xFF               ; Garder unique le nombre max de slots
    mov dword [rbx + XHCI_CONFIG], eax

    mov eax, dword [rbx + XHCI_CONFIG]
    LOG_HEX "[xHCI] Read-back CONFIG (MaxSlots) : ", rax

    ; Enregistrer le tableau DCBAA
    lea rax, [rel xhci_dcbaa]
    VIRT_TO_PHYS rax
    mov qword [rbx + XHCI_DCBAAP], rax

    mov rax, qword [rbx + XHCI_DCBAAP]
    LOG_HEX "[xHCI] Read-back DCBAAP (Phys Addr): ", rax

    ; ------------------------------------------------------------------
    ; Initialisation des Rings
    ; ------------------------------------------------------------------
    call init_xhci_command_ring
    call init_xhci_event_ring


.init_done:
    pop r12
    pop rbx
    ret
; =====================================================================
; FONCTION : reset_xhci
; Rôle : Effectue le reset matériel complet de la puce xHCI
; Paramètres : RDI = Operational Base Address
; Retour : RAX = 1 (Succès), 0 (Timeout/Échec)
; ====================================================================
reset_xhci:
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

