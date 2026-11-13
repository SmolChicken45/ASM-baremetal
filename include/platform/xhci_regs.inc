; ==========================================
; xhci_regs.inc - Registres matériels xHCI
; ==========================================

; Registres Capability (depuis BAR0)
%define XHCI_CAPLENGTH      0x00    ; Capability Register Length
%define XHCI_HCSPARAMS1     0x04    ; Structural Parameters 1
%define XHCI_DBOFF          0x14    ; Doorbell Offset
%define XHCI_RTSOFF         0x18    ; Runtime Register Space Offset

; Registres Opérationnels (depuis Operational Base)
%define XHCI_USBCMD         0x00    ; USB Command Register
%define XHCI_USBSTS         0x04    ; USB Status Register
%define XHCI_CRCR           0x18    ; Command Ring Control
%define XHCI_DCBAAP         0x30    ; Device Context Base Address Array Pointer
%define XHCI_CONFIG         0x38    ; Configure Register
%define XHCI_PORTSC_BASE    0x400   ;

; Bits USBCMD / USBSTS
%define XHCI_CMD_RUN    (1 << 0)    ; Run/Stop              (USBCMD)
%define XHCI_CMD_HCRST  (1 << 1)    ; Host Controller Reset (USBCMD)
%define XHCI_CMD_INTE   (1 << 2)    ; Interrupter Enable    (USBCMD)
%define XHCI_STS_CNR    (1 << 11)   ; Controller Not Ready  (USBSTS)
%define XHCI_STS_EINT   (1 << 3)

; Registres Runtime (depuis Runtime Base)
%define XHCI_IR0_BASE       0x20    ; Base de L'Interrupter 0
%define XHCI_IMAN           0x00    ; Offsets relatifs à l'Interrupter
%define XHCI_IMOD           0x04
%define XHCI_ERSTSZ         0x08
%define XHCI_ERSTBA         0x10
%define XHCI_ERDP           0x18

; Port Status and Control (PORTSC)
%define XHCI_PORTSC_CCS (1 << 0)    ; Current Connect Status
%define XHCI_PORTSC_PR  (1 << 4)    ; Port Reset
%define XHCI_PORTSC_CSC (1 << 17)   ; Connect Status Change
%define XHCI_PORTSC_PLC (1 << 19)   ; Port Link State Change
%define XHCI_PORTSC_PRC (1 << 21)   ; Port Reset Change

%define XHCI_PORTSC_SPEED_SHIFT 10

%define XHCI_PORTSC_SPEED_MASK 0x0F ; Masque pour la vitesse
%define XHCI_PORTSC_MASK 0xFF01FFFF ; Masque pour prserver l'état sans acquitter
%define XHCI_PORTSC_CLEAR_ALL   0xFFFFFFEF  ; Masque pour tout acquitter et forcer PR à 0

; Bits pour Command Ring Control (CRCR)
%define XHCI_CRCR_RCS   (1 << 0)    ; Ring Cycle State

; Bits pour INterrupter Management (IMAN)
%define XHCI_IMAN_IP    (1 << 0)    ; Interrupt Pending (write-1-to-clear)
%define XHCI_IMAN_IE    (1 << 1)    ; Interrupt Enable

; Constantes Générales
%define RESET_TIMEOUT   100000