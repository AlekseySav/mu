	.orig	STACK_SIZE
	.text

start:
	sys	brk; end
	push	2(si)
	pop	(label)
	mov	bx, 3
	sys	seek; 0; 0
	mov	dx, ibuf
	mov	si, ibuf
	j	1f
repeat:
	call	skip_line
1:	call	getchar
	cmp	al, ':
	jne	repeat
get_label:
	call	skip_spaces
	mov	di, (label)
1:	call	getchar
	cmp	al, '\n
	jne	2f
	xor	al, al
2:	scasb
	jne	repeat
	test	al, al
	jne	1b
	sub	si, dx
	mov	(0f), si
	mov	bx, 3
	sys	seek; 0:..; 1
quit:	sys	exit; 0

/* - getchar(internal: si, dx) -> char: al { bx } */
	.text
getchar:
	cmp	si, dx
	jne	1f
	mov	bx, 3
	sys	read; ibuf; 512
	test	ax, ax
	je	quit
	mov	dx, ax
	mov	si, ibuf
	add	dx, si
1:	lodsb
				// pusha; mov (0f), al; mov bx, 1; sys write; 0f; 1; popa
	ret
	.bss
ibuf: .=.+512

/* - skip_line() */
	.text
skip_line:
	cmp	al, '\n
	je	1f
	test	al, al
	je	1f
	call	getchar
	cmp	al, '\n
	jne	skip_line
1:	ret

/* - skip_spaces() */
skip_spaces:
	call	getchar
	cmp	al, '\s
	je	1f
	cmp	al, '\t
	je	1f
	j	skip_spaces
1:	ret


/* - debug */
	.text
hexmap: <0123456789abcdef>
prints:
	pusha
1:	cld lodsb
	test	al, al
	je	1f
	call	putchar
	j	1b
1:	popa
	ret
putchar:
	mov	(1f), al
	mov	bx, 1
	sys	write; 1f; 1
	ret
1:	.byte ..
_base: 16
printn:
	pusha
	call	0f
	popa
	ret
0:	xor	dx, dx
	div	(_base)
	push	dx
	test	ax, ax
	je	1f
	call	printn
1:	pop	ax
	mov	bx, hexmap
	xlat
	j	putchar


0:..
	.bss
label: .=.+2
	.bss; end:
