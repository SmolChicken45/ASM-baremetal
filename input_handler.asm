[BITS 64]

%include "input.inc"

global keyboard_handler
global update_input
global InputState

section .data

	; Mapping
	BTN_LEFT	db 0x4B
	BTN_RIGHT	db 0x4D
	BTN_UP		db 0x48
	BTN_DOWN	db 0x50
	
	BTN_CONFIRM	db 0x2C
	BTN_CANCEL	db 0x2D
	BTN_MENU	db 0x2E
	

	; Joystick
	joystick_y 	db 0
	joystick_x 	db 0
	
	; Keyboard
	key_left 	db 0
	key_right 	db 0
	key_up 		db 0
	key_down 	db 0
	
	; Keyboard			; bitfield
	key_left_events 	db 0
	key_right_events 	db 0
	key_up_events 		db 0
	key_down_events 	db 0
	
	key_confirm 	db 0
	key_cancel		db 0
	key_menu		db 0
	
	key_confirm_events	db 0
	key_cancel_events	db 0
	key_menu_events		db 0
	
InputState:			
	; bitfield :
	; bit 0 -> pressed
	; bit 1 -> hold		
	; bit 2 -> released

	; Action Buttons		; bitfield
	confirm db 0			
	cancel db 0				
	menu db 0				
	
	; Direction				; bitfield
	left_state db 0
	right_state db 0
	up_state db 0
	down_state db 0
	
	
	; Direction				; values
	left_value db 0			; 0 -> 127
	right_value db 0		; "		"
	up_value db 0			; "		"
	down_value db 0			; "		"
	

section .text

keyboard_handler:

	push rax
    push rbx
    push rcx
    push rdx
	
	in al, 0x60
	
	mov bl, al
	and bl, 0x7F
	
	test al, 0x80
	jnz .released
	
.press:
	mov cl, BTN_PRESSED
	mov dl, 1
	call handle_btn
	jmp .done


.released:
	mov cl, BTN_RELEASED
	mov dl, 0
	call handle_btn

.done:

    mov al, 0x20
    out 0x20, al
	
    pop rdx
    pop rcx
    pop rbx
    pop rax
	
	iretq

handle_btn:

	cmp bl, [BTN_LEFT]
	je .left
	
	cmp bl, [BTN_RIGHT]
	je .right

	cmp bl, [BTN_UP]
	je .up

	cmp bl, [BTN_DOWN]
	je .down

	cmp bl, [BTN_CONFIRM]
	je .confirm
	
	cmp bl, [BTN_CANCEL]
	je .cancel
	
	cmp bl, [BTN_MENU]
	je .menu
	
	ret
	
.left:
	mov byte [key_left], dl
	or byte [key_left_events], cl
	ret
	
.right:
	mov byte [key_right], dl
	or byte [key_right_events], cl
	ret
	
.up:
	mov byte [key_up], dl
	or byte [key_up_events], cl
	ret
	
.down:
	mov byte [key_down], dl
	or byte [key_down_events], cl
	ret
	
.confirm:
	mov byte [key_confirm], dl
	or byte [key_confirm_events], cl
	ret
	
.cancel:
	mov byte [key_cancel], dl
	or byte [key_cancel_events], cl
	ret
	
.menu:
	mov byte [key_menu], dl
	or byte [key_menu_events], cl
	ret

update_input:

	call joystick_handler
	call input_resolve_handler
	
	ret

joystick_handler:

	; A implementer plus tard
	ret
input_resolve_handler:

loop_direction:
	mov rcx, 0x04
	mov rsi, 0
	
.loop:
	mov dl, [key_left_events + rsi]
	mov byte [key_left_events + rsi], 0
	mov al, [key_left + rsi]
	
	test dl, BTN_PRESSED
	jnz .pressed
	
	test dl, BTN_RELEASED
	jnz .released
	
	
	test al, al
	jnz .hold
	
	mov byte [left_state + rsi], BTN_NOTPRESSED
	jmp .value
	
.pressed:
	mov byte [left_state + rsi], BTN_PRESSED
	jmp .value
	
.released:
	mov byte [left_state + rsi], BTN_RELEASED
	jmp .value
	
.hold:
	mov byte [left_state + rsi], BTN_HOLD
	
.value:
	
	test al, al
	jz .zero
	
	mov byte [left_value + rsi], 127
	jmp .next
	
.zero:
	mov byte [left_value + rsi], 0
	
	
.next:
	inc rsi
	loop .loop
loop_action:
	mov rcx, 0x03
	mov rsi, 0x00
.loop:

	mov dl, [key_confirm_events + rsi]
	mov byte [key_confirm_events + rsi], 0
	mov al, [key_confirm + rsi]
	
	test dl, BTN_PRESSED
	jnz .pressed
	
	test dl, BTN_RELEASED
	jnz .released
	
	test al, al
	jnz .hold
	
	mov byte [confirm + rsi], BTN_NOTPRESSED
	jmp .next
	
.pressed:
	mov byte [confirm + rsi], BTN_PRESSED
	jmp .next
	
.released:
	mov byte [confirm + rsi], BTN_RELEASED
	jmp .next
	
.hold:
	mov byte [confirm + rsi], BTN_HOLD

.next:
	inc rsi
	loop .loop
	ret