[BITS 64]
DEFAULT REL


section .text
global boot_halt

; Fonction qui sert à débugger pour voir quel chemin le code prend
boot_halt:
    cli
.hang:
    hlt
    jmp .hang