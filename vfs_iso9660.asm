[BITS 64]
DEFAULT REL

global find_file

extern read_cdrom_sector

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

