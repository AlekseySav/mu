	.orig	STACK_SIZE
	.text

start:
	mov	ax, 2(si)
	mov	(0f), ax
	sys	open; 0:..; 0
	mov	bx, ax
	sys	stat; buf
	sys	close
	mov	di, buf

	mov	al, i.flags(di)
	mov	si, flags
	mov	cx, 8
1:	test	al, 0x80
	jne	2f
	movb	(si), '-
2:	inc	si
	shl	al, 1
	loop	1b

	push	i.size(di)
	and	i.links(di), 0xff
	push	i.links(di)

	mov	si, fmt
1:	lodsb
	test	al, al
	je	quit
	cmp	al, '\e
	je	2f
	call	putchar
	j	1b
2:	pop	ax
	push	1b
	j	printn
quit:	sys	close
	sys	exit; 0

putchar:
	mov	(0f), al
	mov	bx, 1
	sys	write; 0f; 1
	ret
0: .byte ..

base: 10
printn:
	xor	dx, dx
	div	(base)
	push	dx
	test	ax, ax
	je	1f
	call	printn
1:	pop	ax
	add	al, '0
	j	putchar


fmt:	<flags: >
flags:	<???idrwx\nlinks: \e\n>
	<size: \e\n\0>

buf: .fill 12
