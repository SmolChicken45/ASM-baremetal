; ==========================================
; xhci_ctx.inc - Structures Mémoire (Contexts)
; ==========================================

; Offsets des Contextes Périphériques
%define CTX_INPUT_CTRL      0x00    ;
%define CTX_ADD_FLAGS       0x04    ;
%define CTX_SLOT            0x20    ;
%define CTX_SLOT_DWORD1     0x24    ;
%define CTX_EP0             0x40    ;
%define CTX_EP0_DWORD1      0x44    ;
%define CTX_EP0_TRDP_LO     0x48    ;
%define CTX_EP0_TRDP_HI     0x4C    ;

; Valeurs et Shifts pour Input Control Context
%define ICS_ADD_SLOT        (1 << 0)
%define ICS_ADD_EP0         (1 << 1)

; Valeur et Shifts pour Slot Context (DWORD 0 & 1)
%define SLOT_SPEED_SHIFT    20
%define SLOT_ENTRIES_SHIFT  27
%define SLOT_PORT_SHIFT     16

; Valeurs et Shifts opur Endpoint Context (DWORD 1)
%define EP_ERR_COUNT_SHIFT  1
%define EP_TYPE_SHIFT       3

%define EP_ERR_COUNT_3      3       ; xHCI recommande 3 essais
%define EP_TYPE_CONTROL     4       ; Control Bidirectionnel (EP0)