[BITS 64]
DEFAULT REL

global load_file

extern read_cdrom_sector
extern malloc

section .bss
align 16
sector_buffer:    resb 2048

section .text


find_file:
; ------------------------------------------------------------------
; find_file
; Entrée : RDI = Pointeur vers le nom du fichier (ex: "STATS.DAT;1", terminé par 0)
; Sorties : 
;   RAX = LBA (Secteur de départ du fichier), ou 0 si introuvable
;   RCX = Taille du fichier en octets
; ------------------------------------------------------------------

    push rbx
    push rdx
    push r8 
    push r9 
    push rsi
    push rdi


    ; Sauvegarder le pointeur du nom de fichier cherché
    mov r8, rdi

    ; lire le secteur 16 (PVD)
    mov rdi, 16
    lea rsi, [rel sector_buffer]
    call read_cdrom_sector
    test rax, rax
    jz .error

    ; Extraire le LBA du Dossier Racine
    ; L'enregistrement du dossier racine commence à l'offset 156 du PVD
    ; le LBA est un entier 32 bits (little endian) situé à l'offset 2 de cet enregistrement
    ; 156 + 2 = 158
    lea rsi, [rel sector_buffer]
    mov eax, dword [rsi + 158]

    ; Lire le secteur du Dossier Racine
    mov rdi, rax
    lea rsi, [rel sector_buffer]
    call read_cdrom_sector
    test rax, rax
    jz .error

    ; Parcourir les enregistrement
    lea rsi, [rel sector_buffer]

.loop_records:
    ; Offset 0 : Longueur de cet enregistrement
    movzx rdx, byte [rsi]
    test rdx, rdx
    jz .error

    ; Offset 25 : Flags (Bit 1 = 1 si c'est sous-dossier)
    mov al, byte [rsi + 25]
    test al, 2
    jnz .next_record    ; dossier on passe pour l'instant

    ; Offset 32 : Longueur du nom du fichier
    movzx rcx, byte [rsi + 32]

    ; Comparer le nom du fichier
    lea r9, [rsi + 33] ; r9 pointe vers le nom sur le CD
    mov r10, r8        ; r10 pointe vers la chaine cherche en entré

.compare_string:
    test rcx, rcx
    jz .check_match_length

    mov al, byte [r9]
    mov bl, byte [r10]

    cmp al, bl
    jne .next_record

    inc r9
    inc r10
    dec rcx
    jmp .compare_string

.check_match_length:
    ; On s'assure que notre chaine d'entrée est bien terminée (byte = 0)
    ; Pour éviter de confondre "STAT" et "STATS.DAT;1"
    mov bl, byte [r10]
    test bl, bl
    jnz .next_record

    ; Offset 2 : LBA du fichier (32 bits little endian)
    mov eax, dword [rsi + 2]
    
    ; Offset 10 : taille du fichier en Octets (32 bits little endian)
    mov ecx, dword [rsi + 10]

    jmp .done

.next_record:
    ; Avancer RSI à la structure suivante
    add rsi, rdx

    ; Sécurité : S'assurer qu'on ne sort pas du secteur (2048 bytes)
    lea r11, [rel sector_buffer + 2048]
    cmp rsi, r11
    jae .error

    jmp .loop_records

.error:
    xor rax, rax
    xor rcx, rcx



.done:

    pop rdi
    pop rsi
    pop r9
    pop r8
    pop rdx
    pop rbx
    ret

; ------------------------------------------------------------------
; load_file
; Entrée : RDI = Pointeur vers le nom du fichier ("STATS.DAT;1", 0)
; Sorties :
;   RAX = Pointeur vers le fichier chargé en RAM (ou 0 si erreur)
;   RCX = Taille exacte du fichier en octets (ou 0 si erreur)
; ------------------------------------------------------------------
load_file:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; trouver le fichier sur le CD
    call find_file
    test rax, rax
    jz .error
    
    mov r12, rax    ; r12 = LBA de départ
    mov r13, rcx    ; r13 = Taille exacte du fichier

    ; Calculer le nombre de secteurs requis : (taille + 2047) / 2048
    mov rax, r13
    add rax, 2047
    mov rcx, 2048
    xor rdx, rdx
    div rcx
    mov r15, rax    ; r15 = Nombre de secteur à lire

    ; Allouer la RAM
    mov rdi, r15
    imul rdi, 2048
    call malloc
    test rax, rax
    jz .error

    mov r14, rax        ; r14 = adresse de base de notre buffer
    mov rbx, rax         ; rbx = curseur d'écriture pour la boucle

.read_loop:
    test r15, r15
    jz .done

    mov rdi, r12        ; LBA actuel
    mov rsi, rbx        ; Destination en RAM actuelle

    call read_cdrom_sector
    test rax, rax
    jz .error

    inc r12
    add rbx, 2048
    dec r15
    jmp .read_loop

.error:
    xor rax, rax
    xor rcx, rcx
    jmp .exit

.done:
    mov rax, r14
    mov rcx, r13

.exit:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

