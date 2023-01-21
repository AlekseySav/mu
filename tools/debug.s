/*
 * usage:
 *	int3 .mm ax, bx, cx, dx, 4(fs:bp) ... Q
 *	call print; <message$>
 */

	.text
.if debug

Q = -1

dbg_si: ..

do_debug:
	pusha
	push	ds
	push	fs
	push	ds
	pop	fs
        mov     bp, sp
	mov	fs, 22(ss:bp)
	mov	si, 20(ss:bp)
	mov	(cs:dbg_si), si
	cld					/* only forward */
1:	push	cs
	pop	ds
	mov	si, (dbg_si)
	seg fs lodsb				/* next command */
	inc	(dbg_si)
	cmp	al, -1
	je	2f				/* stop */
	jmp	dbg_modrm
dbg_end:
	j	1b
2:	inc	(cs:dbg_si)			/* skip last -1 byte */
	mov	bp, sp
	push	(cs:dbg_si)
	pop	20(ss:bp)			/* reset return val */
	pop	fs
	pop	ds
	popa
	iret

dbg_modrm:
	movb	(1f), 0x90
	mov	(3f), 0x9090
 	test	al, 8				/* rm has bits 3,4,5 off */
 	jne	get_seg
4:	mov	(2f), al
	push	7f
 	cmp	al, 6				/* (disp) mod r/m */
 	jne	5f
 	jmp	get_disp2
 5:	mov	bl, al
 	shr	bl, 5
 	and	bx, 6				/* bx=mod<<1 */
 	jmp	dbg_disp(bx)
7:	pop	fs
	pop	ds
	popa
	pusha
	push	ds
	push	fs				/* restore original regs */
	add	sp, 26				/* restore sp */
1:	.byte ..				/* segment */
	.byte 0x8b				/* mov ax, (r/m) */
2: 	.byte ..				/* mod r/m */
3: 	.byte .., ..				/* displacement */
	sub	sp, 26
	call	printn
	mov	ax, 0x0e20
	int	0x10
	jmp	dbg_end

get_seg:
	mov	(1b), al
	seg fs lodsb
	inc	(dbg_si)
	jmp 	4b

get_disp1:
	seg fs lodsb
	inc	(dbg_si)
	mov	(3b), al
	ret

get_disp2:
	seg fs lodsw
	add	(dbg_si), 2
	mov	(3b), ax
1:	ret

dbg_disp:
	1b; get_disp1; get_disp2; 1b


printn:
	mov	cx, 4
2:	push	ax
	shr	ax, 4
	dec	cx
	je	1f
	call	2b
1:	pop	ax
	and	al, 15
	mov	bx, 1f
	seg cs xlat
	mov	ah, 0x0e
	int	0x10
	ret
1:	<0123456789abcdef>

print:
	mov	(dbg_si), si
	pop	si
	pusha
1:	lodsb
	cmp	al, '$
	je	2f
	mov	ah, 0x0e
	mov	bx, 1
	int	0x10
	j	1b
2:	popa
	xchg	si, (dbg_si)
	jmp	(dbg_si)

.endif
