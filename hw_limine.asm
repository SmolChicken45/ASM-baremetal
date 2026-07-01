[BITS 64]

extern get_framebuffer_response

section .bss
global SCR_address
global SCR_width
global SCR_height
global SCR_pitch

SCR_address: resq 1      
SCR_width:   resq 1      
SCR_height:  resq 1      
SCR_pitch:   resq 1

section .text
global init_video

init_video:
    
    mov rax, [get_framebuffer_response]    

    push rbx
    push rcx

    ; prendre le premier écran
    mov rcx, [rax + 16]    ; réponse: écrans
    mov rbx, [rcx]        ; premier écran

    mov rax, [rbx + 0]    ; address
    mov [SCR_address], rax
    
    mov rax, [rbx + 8]    ; width
    mov [SCR_width], rax

    mov rax, [rbx + 16]    ; height
    mov [SCR_height], rax

    mov rax, [rbx + 24]    ; pitch
    mov [SCR_pitch], rax

    pop rcx
    pop rbx
    ret