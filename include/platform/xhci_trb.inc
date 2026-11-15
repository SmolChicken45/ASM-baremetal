; ==========================================
; xhci_trb.inc - Transfer Request Blocks (TRB)
; ==========================================

; TRB Types et Bits
%define TRB_TYPE_NORMAL         1
%define TRB_TYPE_SETUP_STAGE    2
%define TRB_TYPE_DATA_STAGE     3
%define TRB_TYPE_STATUS_STAGE   4
%define TRB_TYPE_LINK           6
%define TRB_TYPE_ENABLE_SLOT    9
%define TRB_TYPE_DISABLE_SLOT   10
%define TRB_TYPE_ADDRESS_DEV    11
%define TRB_TYPE_CONFIG_EP      12
%define TRB_TYPE_TRANSFER_EVENT 32
%define TRB_TYPE_CMD_COMPL      33
%define TRB_TYPE_PORT_STAT      34

; TRB Control Bits (DWORD 3)
%define TRB_CTRL_IOC_BIT        (1 << 5)    ; Interrupt On Completion
%define TRB_CTRL_IDT_BIT        (1 << 6)    ; Immediate Data
%define TRB_CTRL_DIR_IN_BIT     (1 << 16)   ; Direction IN (Data Stage & Status)
%define TRB_CTRL_DIR_OUT_BIT    (0 << 16)   ; Direction OUT

; TRB Bit Shifts (DWORD 3)
%define TRB_TYPE_SHIFT          10
%define TRB_SETUP_TRT_SHIFT     16
%define TRB_SLOT_ID_SHIFT       24

%define TRB_TC_BIT      (1 << 1)    ; Toggle Cycle

; TRB DWORD Offset
%define TRB_DWORD0              0x00
%define TRB_DWORD1              0x04
%define TRB_DWORD2              0x08
%define TRB_DWORD3              0x0C

%define TRB_EVENT_DATA          0x00
%define TRB_EVENT_PARAM         0x04
%define TRB_EVENT_STATUS        0x08
%define TRB_EVENT_CTRL          0x0C

%define TRB_COMPL_CODE_SHIFT    24  ; Shift pour isoler le code de complétion (DWORD 2)
%define TRB_EVENT_SLOT_SHIFT    24  ; Shift pour isoler le Slot ID (DWORD 3)
%define TRB_EVENT_PORT_SHIFT    24  ; Shift pour isoler le Port ID (DWORD 0 pour Port Stat)

; Completion Codes (DWORD 2)
%define COMPL_SUCCESS           1

; Device Initialization States (Internal Driver State)
%define DEV_STATE_IDLE          0
%define DEV_STATE_WAIT_SLOT     1
%define DEV_STATE_WAIT_ADDR     2
%define DEV_STATE_WAIT_DESC     3
%define DEV_STATE_DESC_DONE     4
%define DEV_STATE_WAIT_CONF9    5
%define DEV_STATE_WAIT_CONF_FULL 6
%define DEV_STATE_WAIT_SET_CONF 7
%define DEV_STATE_WAIT_CONF_EP  8