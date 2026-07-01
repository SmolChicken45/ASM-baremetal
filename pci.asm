[BITS 64]

global get_audio_device


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

    ; Activer le Memory Space et le bus Mastering
    ; Offset 0x04 = Registre de Commande PCI
    mov r9b, 0x04
    call pci_read_dword
    or eax, 0x00000006    ; bit 1 (Memory Space Enable + bit 2 (Bus Master Enable)
    call pci_write_dword

    ; Lire le BAR0 (Base Address Register 0) pour trouver le MMIO
    ; Offset 0x10 = BAR0
    mov r9b, 0x10
    call pci_read_dword

    ; Nettoyer les 4 dernier bits (ce sont des flags matériel, pas l'addresse)
    and eax, 0xFFFFFFF0
    mov dword [hda_bar0], eax

    ; Sur les machines virtuelles modernes, le BAR0 est souvent en 64-bits
    ; la partie haute de l'adresse est dans le BAR1
    mov r9b, 0x14
    call pci_read_dword
    shl rax, 32
    mov ebx, dword [hda_bar0]
    or rax, rbx

    mov qword [hda_bar0], rax

.end_pci:
    ret
; ==========================================
; FONCTION : Écrire 32 bits (DWORD) sur le bus PCI
; Paramètres : CL = Bus, DL = Device, R8B = Fonction, R9B = Offset
; EAX = La valeur à écrire
; ==========================================
pci_write_dword:
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

    ret