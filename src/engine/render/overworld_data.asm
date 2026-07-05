[BITS 64]
DEFAULT REL

global player_data

section .data
align 8
player_data:
    .x:        dd 100
    .y:        dd 100
    .w:        dd 21
    .h:        dd 40
    .sprite:   dq 0

    .dir:      dd 0
    .anim:     dd 0
    .world     dd 1