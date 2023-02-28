	.orig	STACK_SIZE
	.text

start:
	sys	brk; end
command:
	mov	sp, STACK_SIZE
	mov	bx, 1
	sys	write; greeting; 3
	xor	bx, bx
	sys	read; buf; 512
	mov	cx, ax
	call	parse
	cmp	(buf), 'c|['d*256]		/* 'cd' -- special case */
	jne	1f
	mov	si, -2(di)
	mov	(0f), si
	sys	chdir; 0:..
	j	command
1:	sys	fork
	test	ax, ax
	jne	command
	sys	exec; prebuf; args
	sys	exit

parse:
	mov	si, buf
	mov	di, args
	mov	ax, si
1:	lodsb
	mov	bx, ctab
	xlat
	cbw
	mov	bx, ax
	add	bx, cact
	call	bx
	j	1b

cstate: .byte 0
cact:
1:	testb	(cstate), -1			/* default */
	jne	0f
	incb	(cstate)
	lea	ax, -1(si)
	stosw
0:	ret
2:	mov	(di), 0				/* \n */
	pop	ax				/* skip return */
3:	movb	(cstate), 0			/* \s */
	movb	-1(si), '\0
	ret

c1 = 1b-cact
c2 = 2b-cact
c3 = 3b-cact

ctab:	.byte	c2, c1, c1, c1, c1, c1, c1, c1, c1, c1, c2, c1, c1, c1, c1, c1
	.byte	c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1
	.byte	c3, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1
	.byte	c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1
	.byte	c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1
	.byte	c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1
	.byte	c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1
	.byte	c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1

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

base: 16
hexmap: <0123456789abcdef>
printn:
	pusha
	call	0f
	popa
	ret
0:	xor	dx, dx
	div	(base)
	push	dx
	test	ax, ax
	je	1f
	call	printn
1:	pop	ax
	mov	bx, hexmap
	xlat
	j	putchar


	.data
greeting: <i: >
prebuf: </bin/>
	.bss
buf: .=.+512
args: .=.+100
	end:
