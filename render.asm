[BITS 64]

global render_frame

extern fb_clear
extern fb_draw_tile
extern fb_draw_sprite



section .data

render_camera:
	dq 0	; x
	dq 0	; y

render_player:
	dd 0	; x
	dd 0	; y
	dd 0	; width
	dd 0	; height
	dq 0	; sprite ptr
	
room_id 	dd 0
game_state	dd 0

section .bss

MAX_ENTITES		equ 128
ENTITY_X		equ 0
ENTITY_Y		equ 4
ENTITY_WIDTH	equ 8
ENTITY_HEIGHT	equ 12
ENTITY_SPRITE	equ 16
ENTITY_PADDING	equ 24
ENTITY_SIZE		equ 32

entity_count:
	resd 1
	
entities:
	resb MAX_ENTITES * ENTITY_SIZE


section .text
render_frame:

	;clear screen
    mov eax, 0x00000000
	call fb_clear
	
	; draw
	call render_map
	call render_entities
	call render_ui
	
	ret
	
render_map:
	;    TODO: draw room tils here later
    ret
	
render_entities:
    ; TODO: draw player/ennemies here later
    ret

render_ui:
    ; TODO: draw UI here later
    ret
    