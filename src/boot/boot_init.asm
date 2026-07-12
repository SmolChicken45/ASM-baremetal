[BITS 64]
DEFAULT REL

extern serial_init
extern init_video
extern init_audio_system
extern memory_init
extern detect_cdrom
extern init_idt


global boot_init

section .text

boot_init:

    ; Permet d'avoir le port série en débuggage bas niveau
    call serial_init
    ; La mémoire pour les autres systèmes
    call memory_init

    ; Vidéo/Audio 
    call init_video
    call init_audio_system

    ; Les Assets
	call detect_cdrom
    test rax, rax
    jz .fail

    ; Les handlers d'interruption
    call init_idt
    sti


    ; Signature de SmolChicken45 pour montrer que le init a fonctionné
    mov al, 0x53
    call serial_write_byte
    mov al, 0x43
    call serial_write_byte
    mov al, 0x34
    call serial_write_byte
    mov al, 0x35
    call serial_write_byte


    mov rax, 1
    ret

.fail:
    xor rax, rax
    ret