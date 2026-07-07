[BITS 64]
DEFAULT REL

global render_overworld_map
global render_overworld_entities
global render_overworld_ui

extern player_data
extern current_world_state
extern fb_draw_sprite

extern current_map_ptr
extern tileset_ptr
extern map_width
extern map_height
extern fb_draw_tile


extern serial_write_qword


section .text

render_overworld_map:

	push r12
	push r13
	push r14
	push r15
	push rbx

	mov r12, qword [rel current_map_ptr]
	mov r13, qword [rel tileset_ptr]

	; Sécurité
	test r12, r12
	jz .done
	test r13, r13
	jz .done

	xor r14, r14
.loop_y:
	cmp r14, qword [rel map_height]
	jge .done

	xor r15, r15

.loop_x:
	cmp r15, qword [rel map_width]
	jge .next_row

	; Trouver l'ID de la tuile dans le fichier .bin
	mov rax, r14
	imul rax, qword [rel map_width]
	add rax, r15

	; On lit 1 octet depuis le pointeur de la carte
	movzx ebx, byte [r12 + rax]

	; Ajouter ignorer l'ID 0x00 comme du noir tout le temps
	; test ebx, ebx
	; jz .skip_tile

	; rdi = px
	mov rdi, r15
	imul rdi, 20

	; rsi = py
	mov rsi, r14
	imul rsi, 20

	; rdx = tile pointeur (pointeur tileset + (ID * 1600))
	mov rax, rbx
	imul rax, 1600		; 20 * 20 pixels * 4 bytes
	mov rdx, r13
	add rdx, rax

	call fb_draw_tile

.skip_tile:
	inc r15
	jmp .loop_x

.next_row:
	inc r14
	jmp .loop_y

.done:
	pop rbx
	pop r15
	pop r14
	pop r13
	pop r12
	ret


render_overworld_entities:
    ; X
    movsxd rdi, dword [rel player_data]
    sar rdi, 8
    sub rdi, 10

    ; Y
    movsxd rsi, dword [rel player_data + 4]
    sar rsi, 8
    sub rsi, 37

    ; Pointeur vers l'image
    mov rdx, qword [rel player_data + 16]

    mov eax, dword [rel player_data + 24]
    imul eax, 53760

    mov ecx, dword [rel player_data + 28]
    imul ecx, 84
    add rax, rcx

    mov ecx, dword [rel current_world_state]
    imul ecx, 336
    add rax, rcx

    add rdx, rax

    ; Largeur
    movsxd rcx, dword [rel player_data + 8]
    
    ; Hauteur
    movsxd r8, dword [rel player_data + 12]

    ; Pitch
    mov r9, 336


    ; Dessiner
    call fb_draw_sprite


    ret

render_overworld_ui:

    ret
