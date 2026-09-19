[BITS 64]

global limine_base_revision
global get_framebuffer_response
global get_memmap_response
global get_kernel_address_response

section .rodata
align 8
limine_base_revision:
    dq 0xf9562b2d5c95a6c8
    dq 0x6a7b384944536bdc
    dq 3 ; Révision 3

section .limine_requests progbits alloc noexec write
align 8

limine_requests_start_marker:
    dq 0xf6b8f4b39de7d1ae
    dq 0xfab91a6940fcb9cf
    dq 0x785c6ed015d3e316
    dq 0x181e920a7852b9d9

framebuffer_request:
    dq 0xc7b1dd30df4c8b88
    dq 0x0a82e883a194f07b
    dq 0x9d5827dcd881dd75
    dq 0xa3148604f6fab11b
    dq 0
get_framebuffer_response:
    dq 0

kernel_address_request:
    dq 0xc7b1dd30df4c8b88
    dq 0x0a82e883a194f07b
    dq 0x71ba76863cc55f63
    dq 0xb2644a48c516a487
    dq 0
get_kernel_address_response:
    dq 0

memmap_request:
	dq 0xc7b1dd30df4c8b88
    dq 0x0a82e883a194f07b
	dq 0x67cf3d9d378a806f
	dq 0xe304acdfc50c3c62
	dq 0
get_memmap_response:
	dq 0

limine_requests_end_marker:
    dq 0xadc0e0531bb10d03
    dq 0x9572709f31764c62