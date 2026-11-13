[BITS 64]
DEFAULT REL


global boot_init
global kernel_phys_offset

extern serial_init
extern init_video
extern init_audio_system
extern memory_init
extern detect_cdrom
extern init_idt
extern get_xhci_device
extern init_xhci
extern pci_xhci_enable_msi
extern start_xhci_run
extern get_kernel_address_response

extern serial_write_byte

section .bss
    kernel_phys_offset: resq 1

section .text

; ---------------------------------------------------------------------
; FONCTION : compute_memory_offset
; Rôle : Calcule l'offset global entre mémoire physique et virtuelle
; ---------------------------------------------------------------------
compute_memory_offset:
    mov rdi, [rel get_kernel_address_response]
    mov rax, qword [rdi + 0x08]     ; Base Physique
    sub rax, qword [rdi + 0x10]     ; - Base Virtuelle
    mov qword [rel kernel_phys_offset], rax
    ret

; ---------------------------------------------------------------------
; FONCTION PRINXIPALE : boot_init
; ---------------------------------------------------------------------
boot_init:

    ; Permet d'avoir le port série en débuggage bas niveau
    call serial_init
    ; La mémoire pour les autres systèmes
    call memory_init

    call compute_memory_offset
    ; Vidéo/Audio 
    call init_video
    call init_audio_system



    ; Les Assets
	call detect_cdrom
    test rax, rax
    jz .fail

    ; Les handlers d'interruption
    call init_idt
    sti

    ; USB
    call get_xhci_device
    call init_xhci

    call pci_xhci_enable_msi
    call start_xhci_run

    ; Signature de SmolChicken45 pour montrer que le init a fonctionné
    mov al, 0x53
    call serial_write_byte
    mov al, 0x43
    call serial_write_byte
    mov al, 0x34
    call serial_write_byte
    mov al, 0x35
    call serial_write_byte
    mov al, 0x0D
    call serial_write_byte
    mov al, 0x0A
    call serial_write_byte


    mov rax, 1
    ret

.fail:
    xor rax, rax
    ret