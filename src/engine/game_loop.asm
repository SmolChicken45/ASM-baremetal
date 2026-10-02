[BITS 64]
DEFAULT REL

extern update_input
extern update_player_logic
extern render_frame
extern present_frame

extern system_ticks

extern xhci_poll_event

section .text
global game_loop

game_loop:
.loop_start:
    mov r15, [system_ticks]

    call xhci_poll_event

    call update_input
    call update_player_logic


    call render_frame
    call present_frame

.wait_vblank:
    cmp r15, [system_ticks]
    jne .loop_start

    hlt
    jmp .wait_vblank