%ifndef XHCI_RING_INC
%include "platform/xhci_ring_mgr.inc"
%endif

%ifndef USB_STRUCTS_INC
%define USB_STRUCTS_INC

%define MAX_USB_DEVICES 16
%define MAX_ENDPOINTS   64  ; Nombre max d'Endpoints actifs simultanément dans tout l'OS


struc usb_endpoint_t
.is_allocated       resb 1
.parent_device      resq 1  ; Pointeur vers le usb_device_t propriétaire
.dci                resb 1  ; Device Context Index (1 à 31)

.tr_mgr             resb tr_manager_t_size
endstruc

; Structure qui représente 1 périphérique USB
struc usb_device_t
    .is_allocated       resb 1  ; 0 = Libre, 1 = Utilisé
    .slot_id            resb 1
    .port_id            resb 1
    .speed              resb 1
    .state              resd 1  ; DEV_STATE_IDLE

    .input_ctx_virt     resq 1
    .output_ctx_virt    resq 1
    .input_ctx_phys     resq 1
    .output_ctx_phys    resq 1

    ; Les tampons de descripteurs
    .device_desc        resb 18
    .config_desc        resb 256


    ; Un tableau de pointeurs vers les usb_endpoint_t alloués
    .endpoints          resq 32
endstruc


%endif