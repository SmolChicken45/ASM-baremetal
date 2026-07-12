[BITS 64]
DEFAULT REL

global boot_halt

section .text

; Fonction qui sert à débugger pour voir quel chemin le code prend
boot_halt:
    cli
.hang:
    hlt
    jmp .hang