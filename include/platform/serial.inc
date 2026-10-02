; Macro pour le port série

%ifndef SERIAL_INC
%define SERIAL_INC

extern serial_write_string
extern serial_write_rax_hex

%macro PRINT_SERIAL 2
    push rax
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11

    mov rax, %1
    mov rcx, %2
    call serial_write_string

    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rax
%endmacro


%macro PRINT_SERIAL_HEX 1
    push rax
    mov rax, %1
    call serial_write_rax_hex
    pop rax
%endmacro

%endif ; SERIAL_INC
