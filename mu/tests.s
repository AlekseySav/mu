/ test & debug api
/ tests requires correct rs232 implementation
/ debug requires correct rs232 & tty implementation
/ test API uses COM2, debug API uses COM1

	.sect	<.tests>

.if tests

shutdown:
	mov	$'\n, al
	call	rs1.put
	mov	$0x2000, ax
	mov	$0x604, dx
	outw
	jmp	.

/ __dumpreg:
/ 	push	ax
/ 	push	dx
/ 0:	mov	ax, ax
/ 	call	rs2.put
/ 	mov	ah, al
/ 	call	rs2.put
/ 	pop	dx
/ 	pop	ax
/ 	ret

/ d.regs:
/ 	movb	$0xc0, 0b+1
/ 1:	call	__dumpreg
/ 	add	$8, 0b+1
/ 	jnc	1b
/ 	ret

/ d.ax:	movb	$0xc0, 0b+1
/ 	jmp	__dumpreg
/ d.cx:	movb	$0xc8, 0b+1
/ 	jmp	__dumpreg
/ d.dx:	movb	$0xd0, 0b+1
/ 	jmp	__dumpreg
/ d.bx:	movb	$0xd8, 0b+1
/ 	jmp	__dumpreg
/ d.sp:	movb	$0xe0, 0b+1
/ 	jmp	__dumpreg
/ d.bp:	movb	$0xe8, 0b+1
/ 	jmp	__dumpreg
/ d.si:	movb	$0xf0, 0b+1
/ 	jmp	__dumpreg
/ d.di:	movb	$0xf8, 0b+1
/ 	jmp	__dumpreg

/ db.init:
/ 	movb	$1, db.i
/ 	mov	$'#, al
/ 	call	rs1.put
/ 	mov	$'\s, al
/ 	jmp	rs1.put

/ break:
/ 	pushf
/ 	testb	$-1, db.i
/ 	je	9f
/ 	pusha
/ 	mov	$db.brm, si
/ 	mov	$10, cx
/ 	mov	$3, bx
/ 	call	tty.write
/ 	popa
/ 	incb	db.br
/ 1:	sti
/ 	testb	$-1, db.br
/ 	jne	1b
/ 9:	popf
/ 	ret

/ debug:
/ 	mov	sp, bp
/ 	add	$10, 14(bp)			/ fix sp
/ 	mov	$tty+3*tty_size, bx
/ 	test	$-1, tty.line(bx)
/ 	je	9f
/ 	mov	$buf, si
/ 	mov	$20, cx
/ 	mov	$3, bx
/ 	call	tty.read
/ 	push	$8f
/ 	lodsb
/ 	cmp	$'c, al
/ 	je	db.continue
/ 	cmp	$'p, al
/ 	je	db.print
/ 	cmp	$'q, al
/ 	je	shutdown
/ 	pop	ax
/ 8:	call	db.init
/ 9:	ret

/ db.continue:
/ 	decb	db.br
/ 9:	ret

/ db.print:
/ 	xor	bx, bx
/ 	mov	si, dx
/ 1:	inc	dx
/ 	lodsb
/ 	cmp	$'\s, al
/ 	je	1b
/ 	cmp	$'\n, al
/ 	je	9b
/ 	cmp	$'*, al
/ 	jne	1f
/ 	inc	bx
/ 	dec	dx
/ 	jmp	1b
/ 1:	dec	dx
/ 	mov	al, ah
/ 	lodsb
/ 	xchg	al, ah
/ 	mov	$db.rw, di			/ register ?
/ 2:	cmp	$db.rw+32, di
/ 	je	9f
/ 	scasw
/ 	jne	2b
/ 	neg	di
/ 	mov	32+db.rw+2(bp,di), ax
/ 	call	db.reg
/ 	jmp	db.print
/ 9:	sub	$2, si				/ symbol ?
/ 	/ mov	$.strtab, di
/ 	xchg	si, di
/ 1:	cmp	$bss, si
/ 	jae	9f
/ 	push	di
/ 	lodsw
/ 	mov	ax, cx
/ 2:	lodsb
/ 	test	al, al
/ 	je	3f
/ 	scasb
/ 	je	2b
/ 2:	lodsb
/ 	test	al, al
/ 	jne	2b
/ 	pop	di
/ 	jmp	1b
/ 3:	cmpb	$'\s, (di)
/ 	je	4f
/ 	cmpb	$'\n, (di)
/ 	je	4f
/ 	pop	di
/ 	jmp	1b
/ 4:	mov	di, si
/ 	pop	dx
/ 	mov	cx, di
/ 1:	test	bx, bx
/ 	je	1f
/ 	mov	(di), di
/ 	dec	bx
/ 	jmp	1b
/ 1:	mov	di, ax
/ 	call	db.reg
/ 	jmp	db.print
/ 9:	ret

/ db.reg:
/ 	push	ax
/ 	push	si
/ 	xchg	dx, si
/ 1:	lodsb
/ 	push	dx
/ 	call	rs1.put
/ 	pop	dx
/ 	cmp	si, dx
/ 	je	1f
/ 	jmp	1b
/ 1:	pop	si
/ 	mov	$'=, al
/ 	call	rs1.put
/ 	pop	ax
/ 	mov	$4, cx
/ 	test	bx, bx
/ 	je	1f
/ 	mov	ax, bx
/ 	mov	(bx), ax
/ 1:	call	db.hex
/ 	mov	$'\n, al
/ 	call	rs1.put
/ 	ret

/ db.hex:
/ 	mov	$hexmap, bx
/ 	push	ax
/ 	shr	$12, ax
/ 	xlat
/ 	call	rs1.put
/ 	pop	ax
/ 	shl	$4, ax
/ 	loop	db.hex
/ 	ret

/ hexmap:	<0123456789abcdef>
/ db.rw:	<flcsip????axcxdxbxspbpsididsesfs>
/ db.brm:	<(break)\n# >
/ buf:	.fill 20
/ db.br:	.fill 1
/ db.i:	.fill 1


/*
 * ddbg -- mmap i/o & send commands
 */
6:	push	dx
	call	rs2.put
	mov	ah, al
	call	rs2.put
	pop	dx
	ret

7:	mov	ax, ds
	xor	si, si
	mov	$512/2, cx
1:	lodsw
	call	6b
	loop	1b
	ret

8:	mov	$COM1+5, dx
	inb
	test	$1, al
	je	8b
	mov	$COM1, dx
	inb
	cmp	$'\d, al
	jne	1f
	mov	$'\b, al
1:	call	rs1.put
	ret

5:	push	ax
	call	6b				/ put base
	mov	bx, ax
	call	6b				/ put count
	pop	ax
1:	push	ax
 	call	7b
 	pop	ax
	add	$512/16, ax
	dec	bx
 	jne	1b
	ret

ddbg:	/ flags
	/ cs
	/ ip
	push	ss
	push	gs
	push	fs
	push	es
	push	ds
	push	di
	push	si
	push	bp
	mov	sp, bp
	add	$[3+5+3]*2, bp
	push	bp
	push	bx
	push	dx
	push	cx
	push	ax
	and	$![1<<8], -2(bp)		/ no trap
	/ greeting
	mov	$'b, al
	call	rs1.put
	/ dump registers
	mov	$[3+5+8], cx
	sub	$[3+5+8]*2, bp
1:	mov	(bp), ax
	call	6b
	add	$2, bp
	loop	1b
	/ dump memory
	xor	ax, ax
	mov	$128, bx
	call	5b				/ kernel memory
seg cs;	mov	current, bx
seg cs;	mov	p.seg(bx), ax
seg cs;	mov	p.break(bx), bx
	cmp	$128, bx
	jbe	1f
	mov	$1, bx				/ task memory
1:	test	bx, bx
	jne	1f
	inc	bx
1:	call	5b
1:	/ read line
	call	8b
	cmp	$'q, al
	je	shutdown
	cmp	$'c, al
	je	9f
	cmp	$'s, al
	jne	2f
	or	$[1<<8], -2(bp)			/ trap
	jmp	9f
2:	cmp	$'\r, al
	jne	3f
	mov	$'\n, al
	call	rs1.put
	call	rs2.put
	jmp	1b
3:	call	rs2.put
	call	8b
	jmp	2b
9:	mov	$-1, al
	call	rs2.put
	mov	$'\n, al
	call	rs1.put
	call	rs2.put
	pop	ax
	pop	cx
	pop	dx
	pop	bx
	add	$2, sp
	pop	bp
	pop	si
	pop	di
	pop	ds
	pop	es
	pop	fs
	pop	gs
	add	$2, sp
	iret

.else
ddbg = intb
.endif
