[BITS 64]
global serial_write_qword
global serial_write_byte
global serial_init

serial_init:
    mov dx, 0x3fb
    mov al, 0x80
    out dx, al
    mov dx, 0x3f8
    mov al, 0x03
    out dx, al
    mov dx, 0x3fb
    mov al, 0x03
    out dx, al
    ret

serial_write_byte:
    push rdx
    push rax
.wait:
    mov dx, 0x3fd
    in al, dx
    test al, 0x20
    jz .wait

    pop rax
    mov dx, 0x3f8
    out dx, al
    
    pop rdx
    ret

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