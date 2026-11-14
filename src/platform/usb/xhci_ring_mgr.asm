[BITS 64]
DEFAULT REL

%include "platform/xhci.inc"
%include "platform/memory.inc"

global tr_init
global tr_enqueue
global er_init
global er_dequeue

section .text

; Paramètres:
; RDI = Pointeur vers la strcutre tr_manager_t
; RSI = Adresse virtuelle du buffer de l'anneau (align 64)
; RDX = Capacité totale
tr_init:
    ; Sauvegarder les bases
    mov [rdi + tr_manager_t.base_virt], rsi
    mov [rdi + tr_manager_t.enqueue], rsi

    mov [rdi + tr_manager_t.capacity], edx
    mov dword [rdi + tr_manager_t.cycle_state], 1 ; Le cycle commence toujours à 1

    ; Calculer l'adresse physique
    mov rax, rsi
    VIRT_TO_PHYS rax
    mov [rdi + tr_manager_t.base_phys], rax

    ; Placer le Link TRB à la fin
    ; rbx = Adresse du dernier TRB = base_virt + ((capacity - 1) * 16)
    dec rdx
    shl rdx, 4
    lea rbx, [rsi + rdx]

    ; Construire le Link TRB (Type 6) pointant vers le début de l'aneau
    mov qword [rbx + TRB_DWORD0], rax    ; Paramètre = base physique de l'anneau
    mov dword [rbx + TRB_DWORD2], 0  ; Status = 0
    mov dword [rbx + TRB_DWORD3], (TRB_TYPE_LINK << TRB_TYPE_SHIFT) | TRB_TC_BIT

    ret


; Paramètres :
; RDI = Pointeur vers la structure tr_manager_t
; RAX = Parameter (QWORD 0)
; R8D = Status (DWORD 2)
; R9D = Control (DWORD 3) - Sauf le BIT CYCLE
tr_enqueue:
    ; Récuperer le pointeur d'insertion actuel
    mov rcx, [rdi + tr_manager_t.enqueue]

    ; Appliquer le bit Cycle actuel au DWORD de contrôle
    mov edx, [rdi + tr_manager_t.cycle_state]
    and edx, 1          ; Sécurité
    or r9d, edx         ; Injecter le bit Cycle

    ; Écrire le TRB en mémoire
    mov qword [rcx + TRB_DWORD0], rax   ; Écrire Parameter
    mov dword [rcx + TRB_DWORD2], r8d   ; Écrire Status
    sfence
    mov dword [rcx + TRB_DWORD3], r9d   ; Écrire Control

    ; Avancer le pointeur d'insertion
    add rcx, 16

    ; Vérifier si on atteint le Link TRB
    ; Adresse du Lnk TRB = base_virt + ((capacity - 1) * 16)
    mov r8d, [rdi + tr_manager_t.capacity]
    dec r8d
    shl r8d, 4
    mov r10, [rdi + tr_manager_t.base_virt]
    lea r10, [r10 + r8] ; r10 = Adresse du Link TRB

    cmp rcx, r10
    jne .done

    ; Gestion du Link TRB
    ; Mettre à jour le Bit Cycle du Link TRB
    mov edx, [rdi + tr_manager_t.cycle_state]
    and edx, 1

    ; Lire le Control DWORD du Link TRB, effacer l'ancien bit C, et mettre le nouveau
    mov r11d, dword [r10 + TRB_DWORD3]
    and r11d, 0xFFFFFFFE
    or r11d, edx
    mov dword [r10 + TRB_DWORD3], r11d

    ; Inverser l'état du cycle du gestionnaire
    xor dword [rdi + tr_manager_t.cycle_state], 1

    ; Remettre le pointeur d'insertion au début de l'anneau
    mov rcx, [rdi + tr_manager_t.base_virt]

.done:
    ; Sauvegarder le nouveau pointeur d'insertion
    mov [rdi + tr_manager_t.enqueue], rcx
    ret

; Paramètres :
; RDI = Pointeur vers er_manager_t
; RSI = Adresse virtuelle du buffer de l'anneau (align 64)
; RDX = Capacité totale (ex:256)
er_init:
    mov [rdi + er_manager_t.base_virt], rsi
    mov [rdi + er_manager_t.dequeue_virt], rsi
    mov [rdi + er_manager_t.capacity], edx
    mov dword [rdi + er_manager_t.cycle_state], 1 ; On s'atend à un bit Cycle = 1

    ; Calculer l'adresse physique
    mov rax, rsi
    VIRT_TO_PHYS rax

    mov [rdi + er_manager_t.base_phys], rax
    mov [rdi + er_manager_t.dequeue_phys], rax
    ret

; Paramètres : RDI = Pointeur vers er_manager_t
; Retour :
;   RAX = Adresse virtuelle du TRB de l'événement, ou 0 si vide
;   RDX = Nouvelle adresse physique (à écrire dans ERDP par l'appelant
er_dequeue:
    ; Lire le TRB au pointeur actuel
    mov rcx, [rdi + er_manager_t.dequeue_virt]

    ; Lire le DWORD 3 et vérifier le bit Cycle
    mov eax, dword [rcx + TRB_DWORD3]
    and eax, 1
    cmp eax, dword [rdi + er_manager_t.cycle_state]
    jne .empty  ; Le bit ne correspond pas = pas de nouvel événement

    ; Un événement est présent
    ; On sauvegarde l'adresse de cet événement pour la retourner dans RAX
    mov r8, rcx

    ; Avancer les pointeurs
    add rcx, 16
    mov r9, [rdi + er_manager_t.dequeue_phys]
    add r9, 16

    ; Vérifier le wrap-around
    mov eax, dword [rdi + er_manager_t.capacity]
    shl rax, 4
    mov r10, [rdi + er_manager_t.base_virt]
    add r10, rax    ; r10 = Adresse de fin stricte

    cmp rcx, r10
    jne .save_pointers

    ; Wrap-around : on remet au début et on inverse le cycle
    mov rcx, [rdi + er_manager_t.base_virt]
    mov r9, [rdi + er_manager_t.base_phys]
    xor dword [rdi + er_manager_t.cycle_state], 1

.save_pointers:
    mov [rdi + er_manager_t.dequeue_virt], rcx
    mov [rdi + er_manager_t.dequeue_phys], r9

    mov rax, r8
    mov rdx, r9
    ret

.empty:
    xor rax, rax
    ret