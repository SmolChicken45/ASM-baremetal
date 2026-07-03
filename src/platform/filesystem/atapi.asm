[BITS 64]
DEFAULT REL

global detect_cdrom
global read_cdrom_sector

section .text

; ------------------------------------------------------------------
; detect_cdrom (VERSION DÉBOGAGE ISOLÉ)
; ------------------------------------------------------------------
detect_cdrom:
	push rbx
	push rcx
    ; On force le test uniquement sur le Secondary Master
    mov bx, 0x170
    mov cl, 0xA0

    ; 1. Sélection
    mov dx, bx
    add dx, 6
    mov al, cl
    out dx, al

    ; Pause
    mov dx, bx
    add dx, 7
    in al, dx
    in al, dx
    in al, dx
    in al, dx

    ; 2. On envoie la commande d'identification
    mov al, 0xA1
    out dx, al

    ; Lecture initiale de l'état
    in al, dx

    ; ==========================================
    ; CHECKPOINT 1 : Bus flottant
    ; ==========================================
    cmp al, 0xFF
    jne .pass_1
    
    hlt         ; <-- DÉCOMMENCE ICI POUR TESTER L'HYPOTHÈSE 1
    jmp $
.pass_1:

    ; ==========================================
    ; CHECKPOINT 2 : Contrôleur présent mais muet
    ; ==========================================
    cmp al, 0x00
    jne .pass_2
    
    hlt       ; <-- DÉCOMMENCE ICI POUR TESTER L'HYPOTHÈSE 2
    jmp $
.pass_2:

    ; ==========================================
    ; CHECKPOINT 3 : Timeout (Le périphérique refuse de répondre)
    ; ==========================================
    mov r9d, 1000000
.wait_bsy:
    in al, dx
    test al, 0x80       ; Bit BSY (Busy)
    jz .pass_3          ; Si 0, il a répondu !
    dec r9d
    jnz .wait_bsy
    
    hlt       ; <-- DÉCOMMENCE ICI POUR TESTER L'HYPOTHÈSE 3 (Timeout)
    jmp $
.pass_3:

; ==========================================
    ; CHECKPOINT 4 : Erreur matérielle (Bit ERR)
    ; La commande 0xA1 a-t-elle été rejetée ?
    ; ==========================================
    test al, 0x01       ; Bit ERR (Erreur, bit 0) est-il à 1 ?
    jz .pass_4
    
    hlt       ; <-- DÉCOMMENCE ICI SI L'APPAREIL REJETTE LA COMMANDE
    jmp $
.pass_4:

    ; ==========================================
    ; CHECKPOINT 5 : Prêt pour les données (Bit DRQ)
    ; Le lecteur demande-t-il à transférer ses infos ?
    ; ==========================================
    test al, 0x08       ; Bit DRQ (Data Request, bit 3) est-il à 1 ?
    jnz .pass_5
    
    hlt       ; <-- DÉCOMMENCE ICI SI LE LECTEUR NE VEUT RIEN ENVOYER
    jmp $
.pass_5:

    ; ==========================================
    ; INITIALISATION : Vider le buffer (512 octets)
    ; C'est cette étape qui débloque officiellement le lecteur.
    ; ==========================================
    mov dx, bx          ; Port Base = Registre de Données (0x170)
    mov rdi, 256        ; On va lire 256 mots (512 octets)
.flush_buffer:
    in ax, dx           ; Lit un mot de 16 bits et l'ignore
    dec rdi
    jnz .flush_buffer

.success:
    ; Si on arrive ici, le lecteur ATAPI est pleinement initialisé !
    mov rax, 1
	pop rcx
	pop rbx
    ret


read_cdrom_sector:
	; ------------------------------------------------------------------
	; read_cdrom_sector
	; Entrées : 
	;   RDI = Numéro de secteur (LBA) à lire (ex: 16)
	;   RSI = Pointeur vers le buffer en RAM (doit faire au moins 2048 octets)
	; Sortie : RAX = 1 (Succès), 0 (Erreur)
	; ------------------------------------------------------------------


	push rbx
	push rcx
	push rdx
	push r8
	push r9
	push rdi
	push rsi

	mov rbx, 0x170
	mov rcx, 0xA0

	; Sélectionner le Drive
	mov dx, bx
	add dx, 6
	mov al, cl
	out dx, al

	; Attendre que le lecteur soit prêt
	mov r9d, 100000
	mov dx, bx
	add dx, 7
.wait_ready:
	in al, dx
	test al, 0x88
	jz .send_packet_cmd
	dec r9d
	jnz .wait_ready
	jmp .error

.send_packet_cmd:
	; Configurer la taille du transfert attendu
	; port base + 4 (LBA Mid) = 0x00
	; port base + 5 (LBA High) = 0x08
	mov dx, bx
	add dx, 4
	mov al, 0x00
	out dx, al
	inc dx
	mov al, 0x08
	out dx, al

	; Envoyer la commande ATAPI PACKET
	mov dx, bx
	add dx, 7
	mov al, 0xA0
	out dx, al

	; Attendre que le lecteur demande le paquet (DRQ=1)
	mov r9d, 1000000
.wait_drq_for_packet:
	in al, dx
	test al, 0x08
	jnz .send_packet_data
	dec r9d
	jnz .wait_drq_for_packet
	jmp .error

.send_packet_data:
	; Construire et envoyer le paquet SCSI READ(12) de 12 octets
	; ATAPI utilse Big-Endian pour LBA
	mov rax, rdi
	bswap eax

	; 6 x 16 bits (6 words), envoyer au port de données
	mov dx, bx

	; Mot 1 : Commande READ(12) = 0xA8
	mov ax, 0x00A8
	out dx, ax

	; Mot 2 : LBA (haute)
	mov eax, edi
	shr eax, 16
	xchg al, ah
	out dx, ax

	; Mot 3 : LBA (basse)
	mov eax, edi
	xchg al, ah
	out dx, ax

	; Mot 4 : taille du transfert (partie haute) On lit 1 secteur (0x00000001)
	mov ax, 0x0000
	out dx, ax

	; Mot 5 : taille du transfert (basse) 1 secteur en big-endian
	mov ax, 0x0100
	out dx, ax

	; Mot 6 : contrôle (0x0000)
	mov ax, 0x0000
	out dx, ax

	mov r9d, 1000000
	mov dx, bx
	add dx, 7
.wait_data_ready:
	in al, dx
	test al, 0x01
	jnz .error
	test al, 0x08
	jnz .read_data
	dec r9d
	jnz .wait_data_ready
	jmp .error

.read_data:
	; Lire les 2048 octets depuis le port de Données vers la RAM
	cld
	mov dx, bx
	mov rdi, rsi
	mov rcx, 1024
	rep insw

	mov rax, 1
	jmp .done

.error:
	xor rax, rax
	hlt

.done:
	pop rsi
	pop rdi
	pop r9
	pop r8
	pop rdx
	pop rcx
	pop rbx
	ret
