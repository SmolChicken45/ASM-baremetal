[BITS 64]
DEFAULT REL

extern keyboard_handler
extern timer_handler

global init_idt

section .bss
align 16
idt: resb 256 * 16

section .data
align 8
idtr:
    dw (256 * 16) - 1
    dq idt


section .text

; Fonction utilitaire pour écrire dans le tableau IDT
; Paramètres : RDI = Index de l'interruption (ex: 0x21)
;              RSI = Adresse de la fonction (ex: keyboard_handler)
set_idt_entry:
    push rax
    push rbx
    push rcx

    ; Calcul de l'adresse de la case : idt + (RDI * 16)
    lea rbx, [rel idt]
    shl rdi, 4
    add rbx, rdi

    ; Offset Low (16 bits inférieurs de l'adresse)
    mov rax, rsi
    mov [rbx], ax

    ; Sélecteur de Segment (16 bits)
    ; Limine configure toujours le segment de code 64 bits à 0x28
    mov word [rbx + 2], 0x28
    
    ; IST (8 bits) = 0
    mov byte [rbx + 4], 0

    ; Type et Attributs (8 buts)
    ; 0x8E = Interrupt Gate 64 bits, Présent, Privilège Ring 0
    mov byte [rbx + 5], 0x8E
    
    ; Offset middle (16 bits)
    shr rax, 16
    mov [rbx + 6], ax

    ; Offset high (32 bits supérieurs)
    shr rax, 16
    mov [rbx + 8], eax

    ; Réservé (32 bits) = 0
    mov dword [rbx + 12], 0

    pop rcx
    pop rbx
    pop rax

    ret

init_idt:
    ; --------------------------------------
    ; ÉTAPE 1 : REPROGRAMMATION DU PIC
    ; --------------------------------------
    ; ICW1 - Initialisation
    mov al, 0x11
    out 0x20, al    ; PIC Master
    out 0xA0, al    ; PIC Slave

    ; ICW2 - Décalage des vecteurs (Master commence à 0x20, Slave à 0x28)
    mov al, 0x20
    out 0x21, al
    mov al, 0x28
    out 0xA1, al

    ; ICW3 - Configuration de la cascade Master/Slave
    mov al, 0x04
    out 0x21, al
    mov al, 0x02
    out 0xA1, al

    ; ICW4 - Mode 8086
    mov al, 0x01
    out 0x21, al
    out 0xA1, al

    ; Activer le Timer (IRQ0) ET le Clavier (IRQ1)
    ; 0xFC = 1111 1100 en binaire (Bits 0 et 1 ouverts)
    mov al, 0xFC
    out 0x21, al    ; Master (Autorise le clavier)
    mov al, 0xFF
    out 0xA1, al    ; Slave (Bloque tout)

    ; --------------------------------------
    ; NOUVEAU : CONFIGURATION DU PIT (60 Hz)
    ; --------------------------------------
    mov al, 0x36            ; Mode 3 (Onde carrée)
    out 0x43, al
    
    mov ax, 19886           ; Diviseur magique pour 60.001 Hz
    out 0x40, al            ; Low byte (0xAE)
    mov al, ah
    out 0x40, al            ; High byte (0x4D)

    ; --------------------------------------
    ; ÉTAPE 2 : ENREGISTREMENT DES HANDLERS
    ; --------------------------------------

    mov rdi, 0x21    ; 0x20 (base du PIC) + 1 (IRQ1)
    lea rsi, [rel keyboard_handler]
    call set_idt_entry

    mov rdi, 0x20
    lea rsi, [rel timer_handler]
    call set_idt_entry

    ; --------------------------------------
    ; ÉTAPE 3 : CHARGEMENT DANS LE CPU
    ; --------------------------------------
    lidt [rel idtr]

    ret