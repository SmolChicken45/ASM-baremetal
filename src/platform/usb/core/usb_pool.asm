[BITS 64]
DEFAULT REL

%include "platform/serial.inc"
%include "platform/xhci.inc"
%include "platform/memory.inc"

; ==============================================
; EXPORTATIONS
; ==============================================
global core_usb_alloc_device
global core_usb_free_device
global core_usb_alloc_endpoint
global core_usb_free_endpoint

global core_usb_get_device_by_port
global core_usb_get_device_by_slot
global core_usb_get_device_waiting_slot

global usb_input_ctx_pool
global usb_output_ctx_pool
global usb_ep_ring_pool


extern hcd_tr_init


; ==============================================
; SECTION DES POOLS EN MÉMOIRE
; ==============================================
section .bss

alignb 16
usb_device_pool:        resb (usb_device_t_size * MAX_USB_DEVICES)

alignb 16
usb_endpoint_pool:      resb (usb_endpoint_t_size * MAX_ENDPOINTS)

alignb 4096
usb_input_ctx_pool:     resb (4096 * MAX_USB_DEVICES)
alignb 4096
usb_output_ctx_pool:    resb (4096 * MAX_USB_DEVICES)

alignb 4096
usb_ep_ring_pool:       resb (4096 * MAX_ENDPOINTS)

section .text
; ==============================================
; SECTION CODE - GESTIONNAIRE DE MÉMOIRE
; ==============================================


; ==============================================
; core_usb_alloc_device
; Retourne :
;       RAX = Pointeur vers usb_device_t, ou 0 si plein
;       RCX = Index (0 à MAX_USB_DEVICES-1)
; ==============================================
core_usb_alloc_device:

    lea r8, [rel usb_device_pool]
    xor rcx, rcx

.loop_dev:
    cmp rcx, MAX_USB_DEVICES
    jae .pool_full

    cmp byte [r8 + usb_device_t.is_allocated], 0
    je .found_dev

    add r8, usb_device_t_size
    inc rcx
    jmp .loop_dev

.found_dev:
    mov byte [r8 + usb_device_t.is_allocated], 1

    mov rax, rcx
    shl rax, 12         ; RAX = Index * 4096
    lea r9, [rel usb_input_ctx_pool]
    add r9, rax         ; Pointeur vers la page 4K
    mov qword [r8 + usb_device_t.input_ctx_virt], r9
    VIRT_TO_PHYS r9
    mov qword [r8 + usb_device_t.input_ctx_phys], r9
    lea r9, [rel usb_output_ctx_pool]
    add r9, rax
    mov qword [r8 + usb_device_t.output_ctx_virt], r9
    VIRT_TO_PHYS r9
    mov qword [r8 + usb_device_t.output_ctx_phys], r9
    mov rax, r8

    ret

.pool_full:
    PRINT_INLINE "[USB Pool] ERREUR : Aucun périphérique disponible."
    xor rax, rax

    ret


; ==============================================
; core_usb_free_device
; Entrée : RDI = Pointeur vers le usb_device_t à libérer
; ==============================================
core_usb_free_device:
    test rdi, rdi
    jz .done_dev
    mov byte [rdi + usb_device_t.is_allocated], 0

    xor rcx, rcx

.free_ep_loop:
    cmp rcx, 32
    jae .done_dev

    mov r8, qword [rdi + usb_device_t.endpoints + rcx * 8]
    test r8, r8
    jz .next_ep

    mov byte [r8 + usb_endpoint_t.is_allocated], 0
    mov qword [rdi + usb_device_t.endpoints + rcx * 8], 0
.next_ep:
    inc rcx
    jmp .free_ep_loop

.done_dev:
    ret


; ==============================================
; core_usb_alloc_endpoint
; Entrée :
;       RDI = Pointeur vers usb_device_t parent
;       RSI = DCI
; Retourne :
;       RAX = Pointeur vers usb_endpoint_t, ou 0 si plein
;       RCX = Index
; ==============================================
core_usb_alloc_endpoint:

    lea r8, [rel usb_endpoint_pool]
    xor rcx, rcx

.loop_ep:
    cmp rcx, MAX_ENDPOINTS
    jae .ep_pool_full

    cmp byte [r8 + usb_endpoint_t.is_allocated], 0
    je .found_ep

    add r8, usb_endpoint_t_size
    inc rcx
    jmp .loop_ep

.found_ep:
    mov byte [r8 + usb_endpoint_t.is_allocated], 1
    mov qword [r8 + usb_endpoint_t.parent_device], rdi
    mov byte [r8 + usb_endpoint_t.dci], sil

    ; Lier l'Endpoint au Device
    mov qword [rdi + usb_device_t.endpoints + rsi * 8], r8

    ; Calculer l'adresse de la page 4K et initialiser tr_mgr
    mov rax, rcx
    shl rax, 12         ; Index * 4096
    lea r9, [rel usb_ep_ring_pool]
    add rax, r9

    push r8

    ; initialiser tr_mgr
    lea rdi, [r8 + usb_endpoint_t.tr_mgr]
    mov rsi, rax
    mov rdx, 256
    call hcd_tr_init

    pop r8
    ; Retourner le pointeur et l'index de l'anneau (rcx)
    mov rax, r8
    ret

.ep_pool_full:
    PRINT_INLINE "[USB Pool] ERREUR : Aucun Endpoint disponible."
    xor rax, rax
    ret


; ==============================================
; core_usb_free_endpoint
; Entré : RDI = Pointeur vers le usb_endpoint_t à libérer
; ==============================================
core_usb_free_endpoint:
    test rdi, rdi
    jz .done_ep
    mov byte [rdi + usb_endpoint_t.is_allocated], 0
.done_ep:
    ret


; ==============================================
; core_usb_get_device_by_port
; Entrée : DIL = Port ID
; Retourne : RAX = Pointeur vers usb_device_t, ou 0 si introuvable
; ==============================================
core_usb_get_device_by_port:
    lea r8, [rel usb_device_pool]
    xor rcx, rcx

.loop_port:
    cmp rcx, MAX_USB_DEVICES
    jae .not_found

    ; Vérifier si l'emplacement est actif
    cmp byte [r8 + usb_device_t.is_allocated], 1
    jne .next_port

    ; Vérifier si le Port ID correspond
    cmp byte [r8 + usb_device_t.port_id], dil
    je .found

.next_port:
    add r8, usb_device_t_size
    inc rcx
    jmp .loop_port

.not_found:
    xor rax, rax
    ret
.found:
    mov rax, r8
    ret


; ==============================================
; core_usb_get_device_by_slot
; Entrée : DIL = Slot ID
; Retourner : RAX = Pointeur vers usb_device_t, ou 0 si introuvable
; ==============================================
core_usb_get_device_by_slot:
    lea r8, [rel usb_device_pool]
    xor rcx, rcx

.loop_slot:
    cmp rcx, MAX_USB_DEVICES
    jae .not_found

    ; Vérifier si l'emplacement est actif
    cmp byte [r8 + usb_device_t.is_allocated], 1
    jne .next_slot

    ; Vérifier si le Port ID correspond
    cmp byte [r8 + usb_device_t.slot_id], dil
    je .found

.next_slot:
    add r8, usb_device_t_size
    inc rcx
    jmp .loop_slot

.not_found:
    xor rax, rax
    ret
.found:
    mov rax, r8
    ret



; ==============================================
; core_usb_get_device_waiting_slot
; Retourne le premier périphérique dont l'état est DEV_STATE_WAIT_SLOT
; Retourne : RAX = Pointeur vers usb_device_t, ou 0 si introuvable
; ==============================================
core_usb_get_device_waiting_slot:
        lea r8, [rel usb_device_pool]
        xor rcx, rcx

    .loop_wait:
        cmp rcx, MAX_USB_DEVICES
        jae .not_found

        ; Vérifier si l'emplacement est actif
        cmp byte [r8 + usb_device_t.is_allocated], 1
        jne .next_wait

        ; Vérifier si le Port ID correspond
        cmp byte [r8 + usb_device_t.state], DEV_STATE_WAIT_SLOT
        je .found

    .next_wait:
        add r8, usb_device_t_size
        inc rcx
        jmp .loop_wait

    .not_found:
        xor rax, rax
        ret
    .found:
        mov rax, r8
        ret