	.orig	STACK_SIZE
	.text

/* - start */
start:
	sys	brk; end
	push	2(si)
	pop	(0f)
	sys	open; 0:..; 0
	test	ax, ax
	js	quit
	mov	bx, ax
go:	sys	read; buf; 512
	cmp	ax, 0
	jle	quit
	mov	cx, ax
	add	cx, 15
	shr	cx, 4
	mov	si, buf
	mov	di, obuf
1:	push	ax
	push	cx
	push	si
	push	si
	mov	cx, ax
	cmp	cx, 16
	jbe	9f
	mov	cx, 16
9:	mov	ax, si
	sub	ax, buf
	call	printn; 4; 2
	push	cx
	call	put_1
	pop	cx
	pop	si
	call	put_2
	mov	al, '\n
	stosb
	pop	si
	pop	cx
	pop	ax
	sub	ax, 16
	add	si, 16
	loop	1b
	call	flush
	j	go
quit:	sys	exit; 0


/* - flush */
flush:
	sub	di, obuf
	mov	(0f), di
	push	bx
	mov	bx, 1
	sys	write; obuf; 0:..
	pop	bx
	ret

/* - printn */
printn:	pop	bp
	push	dx
	push	cx
	push	bx
	mov	cx, 0(bp)
	call	0f
	mov	al, '\s
	stosb
	cmp	2(bp), 1
	je	1f
	stosb
1:	pop	bx
	pop	cx
	pop	dx
	add	bp, 4
	jmp	bp
0:	xor	dx, dx
	div	(base)
	push	dx
	dec	cx
	jcxz	1f
	call	0b
1:	pop	ax
	mov	bx, hexmap
	xlat
	stosb
	ret

/* - put_1 */
put_1:
	mov	dx, 16	
1:	lodsb
	xor	ah, ah
	mov	(0f), 2
	dec	dx
	test	dx, 7
	je	2f
	dec	(0f)
2:	call	printn; 2; 0:..
	loop	1b
	test	dx, dx
	je	4f
	mov	ax, '\s|['\s*256]
1:	stosw
	stosb
	dec	dx
	test	dx, 7
	jne	3f
	stosb
3:	test	dx, dx
	jne	1b
4:	ret

/* - put_2 */
put_2:
	mov	al, '|
	stosb
2:	lodsb
	cmp	al, '\s
	jae	1f
	mov	al, '.
1:	cmp	al, 0x7f
	jb	1f
	mov	al, '.
1:	stosb
	loop	2b
	mov	al, '|
	stosb
	ret


	.data; .even
base:	16
hexmap:	<0123456789abcdef>

	.bss
buf: .=.+512
obuf: .=.+512
end:
