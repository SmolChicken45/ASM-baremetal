[BITS 64]

global get_framebuffer_response
global get_memmap_response
global module_request


section .limine_reqs progbits alloc noexec write
align 8
    dq framebuffer_request
    dq module_request
    dq memmap_request
    dq 0

section .data
align 8
framebuffer_request:
    dq 0xc7b1dd30df4c8b88
    dq 0x0a82e883a194f07b
    dq 0x9d5827dcd881dd75
    dq 0xa3148604f6fab11b
    dq 0
get_framebuffer_response:
    dq 0

module_request:
    dq 0xc7b1dd30df4c8b88
    dq 0x0a82e883a194f07b
    dq 0x3e7e279702be32af
    dq 0xca1c4f3bd1280cee
    dq 0
    dq 0

memmap_request:
	dq 0xc7b1dd30df4c8b88
    dq 0x0a82e883a194f07b
	dq 0x67cf3d9d378a806f
	dq 0xe304acdfc50c3c62
	dq 0
get_memmap_response:
	dq 0