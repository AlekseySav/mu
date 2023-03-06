	.orig	STACK_SIZE
	.text

start:
	sys	brk; end
	cmp	cx, 1
	jle	command
	push	2(si)
	pop	(0f)
	sys	open; 0:..; 0
	mov	(fd), ax
	mov	bx, ax
command:
	sys	sync
	// mov	bx, 2
	// sys	dup2; 0
	// sys	dup2; 1
1:	call	parse
	testb	(argc), -1
	je	command
	mov	bx, (argv)
	cmp	(bx), 'c|['d*256]		/* 'cd' -- special case */
	jne	1f
	mov	si, -2(di)
	mov	(0f), si
	sys	chdir; 0:..
	j	command
1:	mov	bx, (ifile)
	xor	si, si
	call	set_io
	mov	bx, (ofile)
	mov	si, 1
	call	set_io
	sys	fork
	test	ax, ax
	jne	command
	call	do_exec				/* try local */
	sub	(argv), 5
	mov	di, (argv)
	mov	si, bin
	mov	cx, 5
	rep movsb
	call	do_exec				/* try /bin/ */
	sys	exit

	.bss
argbuf: .=.+512
argv: .=.+100
argc: .=.+2
ifile: .=.+2
ofile: .=.+2
state: .=.+2

/* - getchar() -> char: ax */
	.text
getchar:
	push	bx
	test	(istr), -1
	je	1f
	mov	bx, (istr)
	inc	(istr)
	mov	al, (bx)
	test	al, al
	jne	9f
	mov	(istr), 0
1:	mov	bx, (ipos)
	cmp	bx, (ilen)
	jl	1f
	test	(fd), -1
	jne	2f
	mov	(0f), greeting
	testb	(argc), -1
	je	3f
	mov	(0f), continue
3:	mov	bx, 1
	sys	write; 0:..; 3
2:	mov	bx, (fd)
	sys	read; ibuf; 512
	cmp	ax, 0
	ja	4f
	sys	exit
4:	xor	bx, bx
	mov	(ilen), ax
	mov	(ipos), bx
1:	mov	al, ibuf(bx)
	inc	(ipos)
9:	cbw
	pop	bx
	ret
	.bss
istr: .=.+2
ibuf: .=.+512
ipos: .=.+2
ilen: .=.+2

/* - parse() -> argbuf */
	.text
parse:
	mov	(ifile), 0
	mov	(ofile), 0
	movb	(state), 0
	movb	(argc), 0
	mov	si, argbuf+20
	mov	di, argv
	mov	ax, si
1:	call	getchar
	mov	(si), al
	inc	si
	mov	bx, ctab
	xlat
	cbw
	mov	bx, ax
	add	bx, cact
	call	bx
	j	1b
cstate: .byte 0
cact:
8:	call	getchar				/* \ */
1:	testb	(cstate), -1			/* default */
	jne	0f
	lea	ax, -1(si)
	mov	bx, (state)
	shl	bx, 1
	call	stab(bx)
0:	ret					/* unknown */
4:	call	getchar				/* # */
	cmp	al, '\n
	jne	4b
2:	mov	(di), 0				/* \n ; */
	pop	ax				/* skip return */
3:	movb	(cstate), 0			/* \s \t */
	movb	-1(si), '\0
	ret
5:	movb	(state), 1			/* < */
	ret
6:	movb	(state), 2			/* > */
	ret
7:	call	getchar				/* $ */
	mov	bx, argvp
	sub	ax, '0-1
	shl	ax, 1
	add	bx, ax
	push	(bx)
	pop	(istr)
	ret
c0 = 0b-cact
c1 = 1b-cact
c2 = 2b-cact
c3 = 3b-cact
c4 = 4b-cact
c5 = 5b-cact
c6 = 6b-cact
c7 = 7b-cact
c8 = 8b-cact
1:	incb	(cstate)
	stosw					/* state=0 */
	incb	(argc)
	ret
2:	mov	(0f), ax
	sys	open; 0:..; 0 			/* redirect input */
	mov	(ifile), ax
	movb	(state), 0
	ret
3:	mov	(0f), ax			/* redirect output */
	sys	creat; 0:..; 6
	mov	(ofile), ax
	movb	(state), 0
	ret
	.data
stab:	1b; 2b; 3b
ctab:	.byte	c2, c0, c0, c0, c0, c0, c0, c0, c0, c3, c2, c0, c0, c0, c0, c0
	.byte	c0, c0, c0, c0, c0, c0, c0, c0, c0, c0, c0, c0, c0, c0, c0, c0
	.byte	c3, c1, c1, c4, c7, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1
	.byte	c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c2, c5, c1, c6, c1
	.byte	c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1
	.byte	c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c8, c1, c1, c1
	.byte	c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1
	.byte	c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c1, c0

	.text
/* - set_io(fd: si, number: bx) */
set_io:
	test	bx, bx
	je	9f
	//mov ax, si; call printn
//	mov ax, bx; call printn
	mov	(0f), si
				// mov ax, si; call printn
	sys	dup2; 0:..
9:	ret

/* - do_exec() */
	.text
do_exec:
	push	(argv)
	pop	(0f)
	sys	exec; 0:..; argv
	ret


/* - debug */
	.text
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
continue: <.. >
bin: </bin/>
	.bss
fd: .=.+2
end:
