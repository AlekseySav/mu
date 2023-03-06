	.orig	STACK_SIZE
	.text

start:
	dec	cx
	jcxz	9f
	lodsw
8:	lodsw
	mov	(0f), ax
	mov	di, ax
	call	strlen
	mov	(1f), dx
	mov	bx, 1
	sys	write; 0:..; 1:..
	sys	write; s; 1
	loop	8b
9:	sys	write; lf; 1
	sys	exit

strlen:
	xor	al, al
	xor	dx, dx
1:	scasb
	je	1f
	inc	dx
	j	1b
1:	ret

s:	'\s
lf:	'\n
