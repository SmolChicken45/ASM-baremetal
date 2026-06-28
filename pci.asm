[BITS 64]

global get_audio_device


section .bss
global hda_bus
global hda_dev
global hda_func
global hda_found_flag

hda_bus:        resb 1
hda_dev:        resb 1
hda_func:       resb 1
hda_found_flag  resb 1

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
    ret

get_audio_device:

    mov byte [hda_found_flag], 0

    mov cl, 0

.bus_loop:
    mov dl, 0
.device_loop:
    mov r8b, 0
    mov r9b, 0x00

    call pci_read_dword
    cmp ax, 0xFFFF    ; Si le Vendor ID est 0xFFFF, l'emplacement est vide
    je .next_device

    ; Le périphérique existe ! On lit son type (Offset 0x08 contient Class/Subclass)
    mov r9b, 0x08
    call pci_read_dword

    ; EAX contient maintenant : [Classe] [Sous-Classe] [ProgIF] [Revision]
    shr eax, 16    ; On décale pour avoir la Classe et la Sous-Classe dans AX

    cmp ax, 0x0403    ; 0x04 = Multimédia, 0x03 = HDA
    je .hda_found

.next_device:
    inc dl
    cmp dl, 32
    jne .device_loop

    inc cl
    cmp cl, 255
    jne .bus_loop

.hda_found:
    mov byte [hda_bus], cl
    mov byte [hda_dev], dl
    mov byte [hda_func], r8b
    mov byte [hda_found_flag], 1

.end_pci:
    ret