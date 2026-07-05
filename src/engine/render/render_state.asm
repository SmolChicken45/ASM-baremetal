[BITS 64]

global render_map_hook
global render_entities_hook
global render_ui_hook

extern render_overworld_map
extern render_overworld_entities
extern render_overworld_ui


section .data
align 8
render_map_hook:        dq render_overworld_map
render_entities_hook:   dq render_overworld_entities
render_ui_hook:         dq render_overworld_ui