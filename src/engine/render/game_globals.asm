[BITS 64]
DEFAULT REL

global current_world_state
global current_room_id
global current_vfx_mode

section .data
align 4

current_world_state:    dd 0
current_room_id:        dd 0
current_vfx_mode:       dd 0