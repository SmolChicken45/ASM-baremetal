[BITS 64]
DEFAULT REL

%define LIMINE_MEMMAP_USABLE 0

global memory_init
global malloc
global free

extern get_memmap_response

section .bss
align 8
heap_base:       resq 1
heap_size:       resq 1
heap_current:    resq 1

section .text

memory_init:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    ; Lire la réponse de Limine
    mov rax, [rel get_memmap_response]
    test rax, rax
    jz .error

    ; La structure de réponse :
    ; [rax + 0] = Révision
    ; [rax + 8] = Nombre d'entrées
    ; [rax + 16] = Pointeur vers le tableau de pointeurs d'entrées
    mov rcx, [rax + 8]
    mov rsi, [rax + 16]

    xor r8, r8    ; meilleur adresse de base
    xor r9, r9    ; Plus grand taille trouvée

.loop_entries:
    test rcx, rcx
    jz .done_parsing

    mov rdi, [rsi]

    mov rdx, [rdi + 16]
    cmp rdx, LIMINE_MEMMAP_USABLE   
    jne .next_entry

    mov r10, [rdi + 8]
    cmp r10, r9
    jbe .next_entry

    mov r9, r10
    mov r11, [rdi]
    mov r8, r11

.next_entry:
    add rsi, 8
    dec rcx
    jmp .loop_entries

.done_parsing:
    test r9, r9
    jz .error

    mov [rel heap_base], r8
    mov [rel heap_size], r9
    mov [rel heap_current], r8

    mov rax, 1
    jmp .end

.error:
    xor rax, rax

.end:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

malloc:
; ------------------------------------------------------------------
; malloc
; Entrée : RDI = Taille en octets demandée
; Sortie : RAX = Pointeur vers la mémoire allouée (ou 0 si plein)
; ------------------------------------------------------------------
    mov rax, [rel heap_current]

    mov rdx, rax
    add rdx, rdi

    mov rcx, [rel heap_base]
    add rcx, [rel heap_size]
    cmp rdx, rcx
    jae .out_of_memory

    mov [rel heap_current], rdx

    ret

.out_of_memory:
    xor rax, rax
    ret

; ------------------------------------------------------------------
; free
; Entrée : RDI = Pointeur à libérer
; ------------------------------------------------------------------
free:
    ; Un Bump Allocator basique ne peut pas libérer des blocs au milieu.
    ; Il faudrait implémenter une liste chaînée (Headers) pour un vrai free.
    ; Pour l'instant, c'est une fonction fantôme pour respecter ton architecture.
    ret
