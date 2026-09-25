[BITS 64]

%include "platform/serial.inc"

global get_audio_device
global get_xhci_device


section .rodata
    msg_scan_hda_start:     db "[PCI] Scan du bus PCI pour peripherique HDA...", 13, 10
    msg_scan_hda_start_len  equ $ - msg_scan_hda_start

    msg_scan_xhci_start:    db "[PCI] Scan du bus PCI pour périphérique xHCI...", 13, 10
    msg_scan_xhci_start_len equ $ - msg_scan_xhci_start

    msg_hda_found:      db "[PCI] Audio HDA detecte !", 13, 10
    msg_hda_found_len   equ $ - msg_hda_found

    msg_xhci_found:     db "[PCI] Controlleur xHCI détecté !", 13, 10
    msg_xhci_found_len  equ $ - msg_xhci_found

    msg_bar_64:         db "[PCI] BAR0 configure en 64-bit MMIO.", 13, 10
    msg_bar_64_len      equ $ - msg_bar_64

    msg_bar_32:         db "[PCI] BAR0 configure en 32-bit MMIO.", 13, 10
    msg_bar_32_len      equ $ - msg_bar_32

    msg_not_found:      db "[PCI] Aucun peripherique trouve.", 13, 10
    msg_not_found_len   equ $ - msg_not_found




section .bss
global hda_bus
global hda_dev
global hda_func
global hda_found_flag
global hda_bar0

hda_bus:        resb 1
hda_dev:        resb 1
hda_func:       resb 1
hda_found_flag: resb 1
hda_bar0:       resq 1

global xhci_bus
global xhci_dev
global xhci_func
global xhci_found_flag
global xhci_bar0

xhci_bus:        resb 1
xhci_dev:        resb 1
xhci_func:       resb 1
xhci_found_flag: resb 1
xhci_bar0:       resq 1

section .text

; ==========================================
; FONCTION : Lire 32 bits (DWORD) depuis le bus PCI
; Paramètres attendus :
;   CL = Bus (0-255)
;   DL = Device/Périphérique (0-31)
;   R8B = Fonction (0-7)
;   R9B = Offset/Registre (0-255)
; Retourne :
;   EAX = La valeur lue
; ==========================================

pci_read_dword:
    push rbx
    push rdx
    push rcx

    ; Construction de l'adresse (Bit 31 activé = 0x80000000)
    mov eax, 0x80000000

    ; Ajout du Bus (Décalé de 16 bits)
    movzx ebx, cl
    shl ebx, 16
    or eax, ebx

    ; Ajout du Périphérique (Décalé de 11 bits)
    movzx ebx, dl
    shl ebx, 11
    or eax, ebx

    ; Ajout de la Fonction (Décalée de 8 bits)
    movzx ebx, r8b
    shl ebx, 8
    or eax, ebx

    ; Ajout de l'Offset (Aligné sur 4 octets)
    movzx ebx, r9b
    and ebx, 0xFC
    or eax, ebx

    ; On envoie l'adresse au port 0xCF8
    mov dx, 0xCF8
    out dx, eax

    ; On lit la réponse depuis le port 0xCFC
    mov dx, 0xCFC
    in eax, dx

    pop rcx
    pop rdx
    pop rbx
    ret
; ===================
; esi (24 bits) [Classe][Sous-Classe][Prog-IF]
; edi Masque binaire (0xFFFFFF ou 0xFFFF00)
;
; Return
;   RAX = 1 (Trouvé), 0 (Non trouvé)
;   CL  = Bus, DL = Device, R8B = Function
;   R10 = BAR0 MMIO (64-bit)
; ====================
pci_find_device:
    push rbx
    push r11
    push r12

    mov r12d, 0 ; r12w = Bus (0 à 255)

.bus_loop:
    mov dl, 0   ; dl = Device (0 à 31)

.device_loop:
    mov r8b, 0  ; r8b = Function (0)
                ; (Note: étendre à 0..7 si multifonctions requis)

    ; Tester la présence du périphérique (Vendor ID != 0xFFFF)
    mov r9b, 0x00
    mov cl, r12b
    call pci_read_dword
    cmp ax, 0xFFFF
    je .next_device

    ; Lire Class / Subclass / Prog-IF
    mov r9b, 0x08
    mov cl, r12b
    call pci_read_dword

    ; EAX = [Class 31:24] [Subclass 23:16] [ProgIF 15:8] [Revision 7:0]
    shr eax, 8
    and eax, edi
    mov ebx, esi
    and ebx, edi
    cmp eax, ebx
    je .device_found

.next_device:
    inc dl
    cmp dl, 32
    jne .device_loop

    inc r12b
    cmp r12w, 256
    jne .bus_loop

    ; Non trouvé
    xor eax, eax
    pop r12
    pop r11
    pop rbx
    ret

.device_found:
    mov cl, r12b

    ; Activer Memory Space (bit 1) et Bus Mastering (bit 2)
    mov r9b, 0x04
    call pci_read_dword
    or eax, 0x00000006
    call pci_write_dword

    ; Lecture du BAR0 (Offset 0x10)
    mov r9b, 0x10
    call pci_read_dword
    mov r11d, eax

    and eax, 0xFFFFFFF0 ; Retire les 4 bits de flags
    mov r10, rax        ; Partie basse 32 bits

    ; Vérification BAR 64-bit (bits 2:1 == 0b10 -> valeur 0x04)
    and r11d, 0x06
    cmp r11d, 0x04
    jne .pci_success_32

    ; BAR 64-bit : lire la partie haute dans BAR (Offset 0x14)
    mov r9b, 0x14
    call pci_read_dword
    shl rax, 32
    or r10, rax
    PRINT_SERIAL msg_bar_64, msg_bar_64_len
    jmp .pci_success

.pci_success_32:
    PRINT_SERIAL msg_bar_32, msg_bar_32_len

.pci_success:
    mov eax, 1
    pop r12
    pop r11
    pop rbx
    ret



get_audio_device:
    PRINT_SERIAL msg_scan_hda_start, msg_scan_hda_start_len

    mov esi, 0x040300   ; Classe 0x04, Sous-classe 0x03
    mov edi, 0xFFFF00   ; Ignore le Prog-IF
    call pci_find_device

    test eax, eax
    jz .not_found

    ; Sauvegarde des informations HDA
    mov [hda_bus], cl
    mov [hda_dev], dl
    mov [hda_func], r8b
    mov [hda_bar0], r10
    mov byte [hda_found_flag], 1

    PRINT_SERIAL msg_hda_found, msg_hda_found_len
    ret

.not_found:
    mov byte [hda_found_flag], 0
    PRINT_SERIAL msg_not_found, msg_not_found_len
    ret

get_xhci_device:
    PRINT_SERIAL msg_scan_xhci_start, msg_scan_xhci_start_len

    mov esi, 0x0c0330
    mov edi, 0xFFFFFF
    call pci_find_device

    test eax, eax
    jz .not_found

    ; Sauvegarde des informations xHCI
    mov [xhci_bus], cl
    mov [xhci_dev], dl
    mov [xhci_func], r8b
    mov [xhci_bar0], r10
    mov byte [xhci_found_flag], 1

    PRINT_SERIAL msg_xhci_found, msg_xhci_found_len
    ret

.not_found:
    mov byte [xhci_found_flag], 0
    PRINT_SERIAL msg_not_found, msg_not_found
    ret

; ==========================================
; FONCTION : Écrire 32 bits (DWORD) sur le bus PCI
; Paramètres : CL = Bus, DL = Device, R8B = Fonction, R9B = Offset
; EAX = La valeur à écrire
; ==========================================
pci_write_dword:
    push rbx
    push rdx
    push rcx
    push r10

    mov r10d, eax    ; Sauvegarde la valeur à écrire
    
    ; Construction de l'adresse
    mov eax, 0x80000000
    
    movzx ebx, cl
    shl ebx, 16
    or eax, ebx
    
    movzx ebx, dl
    shl ebx, 11
    or eax, ebx

    movzx ebx, r8b
    shl ebx, 8
    or eax, ebx
    
    movzx ebx, r9b
    and ebx, 0xFC
    or eax, ebx

    mov dx, 0xCF8
    out dx, eax

    ; Écriture de la valeur
    mov eax, r10d
    mov dx, 0xCFC
    out dx, eax

    pop r10
    pop rcx
    pop rdx
    pop rbx

    ret