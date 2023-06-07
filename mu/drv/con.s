/ console -- char output device
/ con.init(x: al, y: ah)
/ con.flush()				{ ax, dx }
/ con.put(char: al, fs=ds)

	.sect	<.init>

con.init:
	mov	al, bl
	shl	$1, bl
	xor	bh, bh
	xchg	al, ah
	mulb	width
	add	bx, ax
	mov	ax, cursor
	ret

	.sect	<.text>

con.flush:
	push	di
	push	cx
	mov	cursor, di
	shr	$1, di
	mov	$15, cl
	mov	di, ax
	call	vga.outb
	dec	cl
	mov	ah, al
	call	vga.outb
	pop	cx
	pop	di
	ret

con.put:
	push	es
	push	di
	push	bx
	push	ax
	mov	$con.tab, bx
	les	cursor, di
	cmp	$'\s, al
	jb	2f
	mov	attr, ah
	stosw
3:	mov	di, cursor
	pop	ax
	pop	bx
	pop	di
	pop	es
	ret
2:	xlat cbw
	add	$0f, ax
	push	$3b
	jmp	ax

0:
c.bs:	sub	$2, di
	seg	es
	testb	$-1, (di)
	je	c.bs
1:	seg	es
	mov	$0x0720, (di)
c.no:	ret
c.ht:	mov	$0x0720, ax
1:	stosw
	xor	al, al
	test	$[tab_size*2-1], di
	jne	1b
	ret
c.lf:	add	$160, di
c.cr:	mov	di, ax
	divb	width
	mov	ah, al
	cbw
	sub	ax, di
	ret

/ cl=command, al=data
vga.outb:
	mov	$0x3d4, dx
	xchg	al, cl
	cli
	outb
	mov	$0x3d5, dx
	xchg	al, cl
	outb
	sti
	ret

	.sect	<.bss>
1:	.=.+2

	.sect	<.data>
width:	160
cursor:	0; 0xb800
attr:	7

con.tab:
	.byte c.no-0b, c.no-0b, c.no-0b, c.no-0b
	.byte c.no-0b, c.no-0b, c.no-0b, c.no-0b
	.byte c.bs-0b, c.ht-0b, c.lf-0b, c.no-0b
	.byte c.no-0b, c.cr-0b, c.no-0b, c.no-0b
	.byte c.no-0b, c.no-0b, c.no-0b, c.no-0b
	.byte c.no-0b, c.no-0b, c.no-0b, c.no-0b
	.byte c.no-0b, c.no-0b, c.no-0b, c.no-0b
	.byte c.no-0b, c.no-0b, c.no-0b, c.no-0b
