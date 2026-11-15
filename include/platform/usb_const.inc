%ifndef USB_CONST_INC
%define USB_CONST_INC

; ============================================
; USB 2.0 / 3.0 Standard Device Requests
; ============================================

; bmRequestType (Bitmapped)
; Bits 0-4 : Recipient (0 = Device, 1 = Interface, 2 = Endpoint, 3 = Other)
; Bits 5-6 : Type (0 = Standard, 1 = Class, 2 = Vendor)
; Bit 7 : Direction (0 = Host-to-Device, 1 = Device-to-Host)
%define USB_REQ_DIR_OUT             (0 << 7)
%define USB_REQ_DIR_IN              (1 << 7)

%define USB_REQ_TYPE_STD            (0 << 5)
%define USB_REQ_TYPE_CLASS          (1 << 5)
%define USB_REQ_TYPE_VENDOR         (2 << 5)

%define USB_REQ_REC_DEVICE          0
%define USB_REQ_REC_INTERFACE       1
%define USB_REQ_REC_ENDPOINT        2
%define USB_REQ_REC_OTHER           3

; Standard bRequest Values
%define USB_REQ_GET_STATUS          0
%define USB_REQ_CLEAR_FEATURE       1
%define USB_REQ_SET_FEATURE         3
%define USB_REQ_SET_ADDRESS         5
%define USB_REQ_GET_DESCRIPTOR      6
%define USB_REQ_SET_DESCRIPTOR      7
%define USB_REQ_GET_CONFIGURATION   8
%define USB_REQ_SET_CONFIGURATION   9

; Descriptor Types (wValue High Byte)
%define USB_DESC_DEVICE             1
%define USB_DESC_CONFIGURATION      2
%define USB_DESC_STRING             3
%define USB_DESC_INTERFACE          4
%define USB_DESC_ENDPOINT           5
%define USB_DESC_HID                0x21
%define USB_DESC_HID_REPORT         0x22

; Configuration Values
%define USB_CFG_VAL_DEFAULT         1

; Class-Specific Requests (HID)
%define HID_REQ_GET_REPORT          0x01
%define HID_REQ_SET_PROTOCOL        0x0B

; USB Endpoint Transfer Types
%define USB_EP_ATTR_CONTROL         0x00
%define USB_EP_ATTR_ISOCHRONOUS     0x01
%define USB_EP_ATTR_BULK            0x02
%define USB_EP_ATTR_INTERRUPT       0x03

; ============================================
; xHCI Setup Stage TRB Constants
; ============================================
; TRB Type 2 (Setup Stage)
%define TRT_NO_DATA                 0
%define TRT_OUT_DATA                2
%define TRT_IN_DATA                 3

; ============================================
; Offsets des champs dansles descripteurs USB
; ============================================

; Configuration Descriptor
%define USB_DESC_CFG_TOTALLEN_OFS   2   ; wTotalLength (Word)

; Endpoint Descriptor
%define USB_DESC_EP_LENGTH_OFS      0   ; bLenght (Byte)
%define USB_DESC_EP_TYPE_OFS        1   ; bDescriptorType (Byte)
%define USB_DESC_EP_ADDR_OFS        2   ; bEndpointAddress (Byte)
%define USB_DESC_EP_ATTR_OFS        3   ; bmAttributes (Byte)
%define USB_DESC_EP_MAXPKT_OFS      4   ; wMaxPacketSize (Word)
%define USB_DESC_EP_INTERVAL_OFS    6   ; bInterval (Byte)

%endif

; =============================================================================
; Constantes de Vitesses USB (Identifiants PORTSC xHCI)
; =============================================================================
%define XHCI_SPEED_FULL             1   ; 12 Mbps
%define XHCI_SPEED_LOW              2   ; 1.5 Mbps
%define XHCI_SPEED_HIGH             3   ; 480 Mbps
%define XHCI_SPEED_SUPER            4   ; 5 Gbps
%define XHCI_SPEED_SUPER_PLUS       5   ; 10 Gbps

; Tailles maximales par défaut des paquest pour Endpoint 0
%define USB_EP0_MAX_FS_LS           8   ; Full/Low Speed
%define USB_EP0_MAX_HS              64  ; High Speed
%define USB_EP0_MAX_SS              512 : SuperSpeed