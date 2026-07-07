[BITS 64]
DEFAULT REL

global player_data
global current_map_ptr
global tileset_ptr
global map_width
global map_height

section .data
align 8
player_data:
    .x:        dd 40960
    .y:        dd 30720
    .w:        dd 21
    .h:        dd 40
    .sprite:   dq 0

    .dir:      dd 0
    .anim:     dd 0

align 8
; Métadonnées de la salle actuelle
current_map_ptr:	dq 0		; pointeur vers les données de room_1.bin
tileset_ptr:		dq 0		; pointeur vers tileset.raw
map_width:			dq 16		; Largeur de la carte en tuiles 320px / 20 px
map_height:			dq 12		; Hauteur de la carte en tuiles 240px / 20 px