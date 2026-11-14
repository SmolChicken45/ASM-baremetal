%ifndef XHCI_RING_INC
%define XHCI_RING_INC

struc tr_manager_t
    .base_virt      resq 1
    .base_phys      resq 1
    .enqueue        resq 1
    .cycle_state    resd 1
    .capacity       resd 1
endstruc

struc er_manager_t
    .base_virt      resq 1  ; Adresse virtuelle du segment ERST
    .base_phys      resq 1  ; Adresse physique du segment
    .dequeue_virt   resq 1  ; Pointeur virtuel vers le prochain événement
    .dequeue_phys   resq 1  ; Pointeur physique
    .cycle_state    resd 1  ; Bit cycle attendu
    .capacity       resd 1  ; Nombre de TRBs dans le segment
endstruc

%endif