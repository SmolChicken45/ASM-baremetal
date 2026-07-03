[BITS 64]
DEFAULT REL

global init_audio_system

extern hda_bar0
extern get_audio_device
extern malloc
extern serial_write_qword
extern get_kernel_address_response

section .bss
align 128
corb_buffer:    resb 1024
align 128
rirb_buffer:    resb 2048

section .data
rirb_software_rp dw 0

section .text
; ------------------------------------------------------------------
; init_audio_system
; Initialise tout le sous-système audio de A à Z
; Retourne : RAX = 1 (Succès), 0 (Échec)
; ------------------------------------------------------------------
init_audio_system:
    push rbx
    push r10

    call get_audio_device
    call reset_controller
    test rax, rax
    jz .error


    ; call setup_corb_rirb


    mov eax, 0x0000F000
    call hda_send_verb_icm
    ; call hda_read_response

	
    call serial_write_qword 

    mov rax, 1
    jmp .end
.error:
    xor rax, rax
.end:
    pop r10
    pop rbx
    ret

; ------------------------------------------------------------------
; reset_controller
; Réinitialise le contrôleur High Definition Audio via le MMIO
; Retourne : RAX = 1 (Succès), 0 (Timeout/Erreur)
; ------------------------------------------------------------------
reset_controller:
    push rbx
    push rdx
    push r8

    ; Récupérer l'adresse MMIO de base
    mov rbx, [rel hda_bar0]
    test rbx, rbx
    jz .error

    
    ; Éteindre le contrôleur (CRST = 0)
    ; Registre GCTL (Global Control) = BAR0 + 0x08 (32 bits)
    mov edx, dword [rbx+ 0x08]
    and edx, 0xFFFFFFFE        ; mettre le bit 0 (CRST) à 0
    mov dword [rbx + 0x08], edx

    mov r8d, 10000000
.wait_reset_0:
    mov edx, dword [rbx + 0x08]
    test edx, 1
    jz .reset_0_ok
    dec r8d
    jnz .wait_reset_0
    jmp .error

.reset_0_ok:
    ; Petite pause supplémentaire recommandée par Intel (au moins 100 microsecondes)
    ; Dans un vrai OS, on utilise un timer PIT/APIC. Ici on fait une boucle d'attente basique.
    mov r8d, 1000
.delay:
    in al, 0x80
    dec r8d
    jnz .delay

    mov edx, dword [rbx + 0x08]
    or edx, 1
    mov dword [rbx + 0x08], edx

    mov r8d, 10000000

.wait_reset_1:
    pause
    ; Rallumer le contrôleur (CRST = 0)
    mov edx, dword [rbx + 0x08]
    test edx, 1
    jnz .success
    dec r8d
    jnz .wait_reset_1
    jmp .error

.success:

    mov r8d, 1000000
.wait_codec:
    mov ax, word [rbx + 0x0E]
    test ax, 1
    jnz .codec_ready
    dec r8d
    jnz .wait_codec
    jmp .error

.codec_ready:
    ; Le codec est là Il faut effacer le bit d'alete en écrivant 1 dessus
    mov word [rbx + 0x0E], ax

    mov rax, 1
    jmp .end

.error:
    xor rax, rax


.end:
    pop r8
    pop rdx
    pop rbx
    ret


setup_corb_rirb:
    push rbx
    push r10
    push r11
    push r12
    push rdi

    mov rbx, [rel hda_bar0]

    mov byte [rbx + 0x4C], 0
    mov byte [rbx + 0x5C], 0

    mov rdi, [rel get_kernel_address_response]
    mov r11, [rdi + 0x10]    ; r11 = virtual_base
    mov r12, [rdi + 0x08]    ; r12 = physical_base

    ; COnfiguration du CORB
    lea r10, [corb_buffer]

    sub r10, r11        ; on enlève la base virtuelle
    add r10, r12        ; on ajoute la base physique

    mov dword [rbx + 0x40], r10d
    shr r10, 32
    mov dword [rbx + 0x44], r10d    ; CORBUBASE

    ; Configuration du RIRB
    lea r10, [rirb_buffer]    ; Addresse vituelle
    
    sub r10, r11
    add r10, r12
    
    mov dword [rbx + 0x50], r10d
    shr r10, 32
    mov dword [rbx + 0x54], r10d

    ; Tailles et Démarrage
    ;Configurer la taille à 256 entrées
    mov byte [rbx + 0x4E], 0x02    ; CORBSIZE
    mov byte [rbx + 0x5E], 0x02    ; RIRBSIZE

    ; Reset du pointeur de lecture du CORB
    mov word [rbx + 0x48], 0        ; CORBBWP = 0
    mov word [rbx + 0x4A], 0x8000    ; CORBRP = 15 ième bit actif
    mov ecx, 1000
.wait_corbrp_1:
    mov ax, word [rbx + 0x4A]
    test ax, 0x8000
    jnz .corbrp_1_ok
    dec ecx
    jnz .wait_corbrp_1
.corbrp_1_ok:

    mov word [rbx+ 0x4A], 0x0000    ; désactiver
    mov ecx, 1000
.wait_corbrp_0:
    mov ax, word [rbx + 0x4A]
    test ax, 0x8000
    jz .corbrp_0_ok
    dec ecx
    jnz .wait_corbrp_0     
.corbrp_0_ok:

	; reset du pointeur d'écriture du RIRB
	mov word [rbx + 0x58], 0x8000

	mov ecx, 1000
.wait_rirbwp_1:
	mov ax, word [rbx + 0x58]
	test ax, 0x8000
	jnz .rirbwp_1_ok
	dec ecx
	jnz .wait_rirbwp_1

.rirbwp_1_ok:

	mov word [rbx + 0x58], 0x0000
	mov ecx, 1000

.wait_rirbwp_0:
	mov ax, word [rbx + 0x58]
	test ax, 0x8000
	jz .rirbwp_0_ok
	dec ecx
	jnz .wait_rirbwp_0

.rirbwp_0_ok:


    ; Démarrer le moteur DMA
    mov byte [rbx + 0x4C], 0x02    ; CORBCTL
    mov byte [rbx + 0x5C], 0x02    ; RIRBCTL

    pop rdi
    pop r12
    pop r11
    pop r10
    pop rbx
    ret
    

; ------------------------------------------------------------------
; hda_send_verb
; Entrée : EAX = Le Verb (32 bits) à envoyer
; ------------------------------------------------------------------
hda_send_verb:
    push rbx
    push rcx
    push rdx

    mov rbx, [rel hda_bar0]

    movzx rcx, word [rbx + 0x48]
    
    inc ecx
    and rcx, 0xFF

    lea rdx, [rel corb_buffer]
    mov [rdx + rcx * 4], eax

    mov word [rbx + 0x48], cx

    pop rdx
    pop rcx
    pop rbx
    ret

; ------------------------------------------------------------------
; hda_read_response
; Retour : EAX = La réponse (32 bits utiles sur les 64 bits du RIRB)
; ------------------------------------------------------------------
hda_read_response:
    push rbx
    push rcx
    push rdx
    push r8

    mov rbx, [rel hda_bar0]
    mov r8d, 10000000
    
.wait_for_response:
    ; Regarder ou est le pointeur d'écriture matériel
    movzx rcx, word [rbx + 0x58]
    ; si le pointeur matériel est au même endroit que notre pointeur logiciel
    ; c'est qui n'a pas de réponse
    cmp cx, word [rel rirb_software_rp]
    jne .got_response
    dec r8d
    jnz .wait_for_response
    
    ; 1. Status du CORB (8 bits)
    movzx eax, byte [rbx + 0x4D]
    call serial_write_qword

    ; 2. Status du RIRB (8 bits)
    movzx eax, byte [rbx + 0x5D]
    call serial_write_qword

    ; 3. Status des Interruptions Générales (32 bits)
    mov eax, dword [rbx + 0x20]
    call serial_write_qword

    hlt

    mov eax, 0xFFFFFFFF
    jmp .end

.got_response:
    ; le matériel a avancé on met à jour
    mov word [rel rirb_software_rp], cx

    lea rdx, [rel rirb_buffer]
    mov rax,  [rdx + rcx * 8]

    mov word [rbx + 0x5A], cx

    mov byte [rbx + 0x5D], 0x01

    ; le RIRB stocke la vraie réponse dans les 32 bits du bas
    ; les 32 bits du haut contiennent des métadonnées qu'on ignore pour l'instant
.end:
    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret

; ------------------------------------------------------------------
; hda_send_verb_icm (Immediate Command Mechanism)
; Entrée : EAX = Le Verb (32 bits) à envoyer
; Retour : EAX = La réponse (32 bits), ou 0xFFFFFFFF si erreur
; ------------------------------------------------------------------
hda_send_verb_icm:
	push rbx
	push rdx
	push rcx
	
	mov rbx, [rel hda_bar0]

	mov edx, 1000000
.wait_ready:
	mov cx, word [rbx + 0x68]
	test cx, 1
	jz .send
	dec edx
	jnz .wait_ready
	jmp .error

.send:
	; Effacer le bit de réponse valide s'il était allumé
	mov word [rbx + 0x68], 2
	
	; Écrire le Verb dans le registre IC (0x60)
	mov dword [rbx + 0x60], eax
	
	; Mettre le bit ICB à 1 pour déclencher l'envoi
	mov cx, word [rbx + 0x68]
	or cx, 1
	mov word [rbx + 0x68], cx

	; Attendre le matéirel remette ICB à 0 ET que IRV passe à 1
	mov edx, 1000000
.wait_response:
	mov cx, word [rbx + 0x68]
	test cx, 1
	jnz .continue_wait
	test cx, 2
	jnz .got_response
.continue_wait:
	dec edx
	jnz .wait_response
	jmp .error

.got_response:
	; Lire la réponse dans IR (0x64)
	mov eax, dword [rbx + 0x64]
	jmp .end

.error:
	hlt
	mov eax, 0xFFFFFFFF
.end:
	pop rcx
	pop rdx
	pop rbx
	ret
    