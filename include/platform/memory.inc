; memory.inc

%ifndef MEMORY_INC
%define MEMORY_INC

extern kernel_phys_offset

; macro pour convertir Virtuel -> Physique
%macro VIRT_TO_PHYS 1
    add %1, qword [rel kernel_phys_offset]
%endmacro

%endif

