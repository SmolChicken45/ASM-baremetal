[BITS 64]
global serial_write_rax_hex
global serial_write_string
global serial_write_qword
global serial_write_byte
global serial_init

section .data
    hex_buffer:     db "0x0000000000000000", 13, 10
    hex_buffer_len  equ $ - hex_buffer

section .text
; -------------------------------------
; Fonction qui initialise le port série
;
; Arguments:
; null
;
; Returns:
; null
; -------------------------------------
serial_init:

    ; Activer le mode configuration du COM1
    mov dx, 0x3fb   ; Line Control Register
    mov al, 0x80    ; Divisor Latch Access Bit
    out dx, al
    
    ; Définir la Vitesse
    mov dx, 0x3f8   
    mov al, 0x03    ; Puce Série a 115 200 Hz
    out dx, al      ; 115 200 Hz / 3 = 38 400 bauds
    
    ; Configurer et enlever le mode configuration
    mov dx, 0x3fb   ; Line Control Register
    mov al, 0x03    ; Format 8-N-1
    out dx, al
    
    ret

; ---------------------------------------------
; Fonction qui écrit un Byte dans le port série
;
; Arguments:
; al = byte à envoyer
;
; Returns:
; null
; ---------------------------------------------
serial_write_byte:
    push rdx
    push rax
.wait:
    ; Attendre que le port série soit prêt
    mov dx, 0x3fd
    in al, dx
    test al, 0x20
    jz .wait

    ; Écrit le byte sur le port série
    pop rax
    mov dx, 0x3f8
    out dx, al
    
    pop rdx
    ret

; ---------------------------------------------
; Fonction qui écrit un Qword dans le port série
;
; Arguments:
; rax = qword à envoyer
;
; Returns:
; null
; ---------------------------------------------
serial_write_qword:

    push rbx

    mov rbx, rax
    
    call serial_write_byte

    mov al, bh
    call serial_write_byte

    shr rbx, 16
    mov al, bl
    call serial_write_byte

    mov al, bh
    call serial_write_byte

    shr rbx, 16
    mov al, bl
    call serial_write_byte

    mov al, bh
    call serial_write_byte

    shr rbx, 16
    mov al, bl
    call serial_write_byte

    mov al, bh
    call serial_write_byte
    
    pop rbx

    ret
    

; ---------------------------------------------
; Fonction qui écrit une suite de caractères dans le port série
;
; Arguments:
; rax = ptr vers le string qui est fini par un zéro
; rcx = nombre maximal de caractère à envoyer
; Returns:
; null
; ---------------------------------------------
serial_write_string:
    push rbx
    push rcx
    
    mov rbx, rax    ; pointeur du char courrant
    
.loop:
    ; Test nbre caractère max
    test rcx, rcx
    jz .done
    
    ; Test de fin de caractère (0x00)
    mov al, [rbx]
    test al, al
    jz .done
    
    call serial_write_byte
    
    inc rbx
    dec rcx
    jmp .loop
    
.done:
    pop rcx
    pop rbx
    ret
    

serial_write_rax_hex:
    push rax
    push rcx
    push rdx
    push rdi
    push r8
    push r9
    push r10
    push r11

    mov rcx, 16
    lea rdi, [rel hex_buffer + 17]

.hex_loop:
    mov rdx, rax
    and rdx, 0x0F
    add dl, '0'
    cmp dl, '9'
    jbe .store_char
    add dl, 7

.store_char:
    mov byte [rdi], dl
    dec rdi
    shr rax, 4
    dec rcx
    jnz .hex_loop

    lea rax, [rel hex_buffer]
    mov rcx, hex_buffer_len
    call serial_write_string

    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rdx
    pop rcx
    pop rax
    ret