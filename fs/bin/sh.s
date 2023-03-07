	.orig	STACK_SIZE
	.text

start:
	sys	brk; end
	dec	cx
	mov	(this_argc), cx
	jcxz	command
	push	2(si)
	pop	(0f)
	sys	open; 0:..; 0
	mov	(ifd), ax
	mov	bx, ax

/* - command */
	.text
command:
	sys	sync
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
1:	cmp	(bx), 'q			/* 'q' -- special case */
	je	quit
	cmp	(bx), 's			/* 's' -- special case */
	jne	1f
	add	(_argvp), 2
	j	command
1:	sys	fork
	test	ax, ax
	jne	command
	call	do_exec				/* try ./ */
	sub	(argv), 5
	mov	di, (argv)
	mov	si, bin
	mov	cx, 5
	rep movsb
	call	do_exec				/* try /bin/ */
quit:	sys	exit; 0
	.data
bin: </bin/>
_argvp: argvp

	.bss
this_argc: .=.+2
prefix: .=.+20
argbuf: .=.+512
argv: .=.+100
argc: .=.+2
state: .=.+2


/* - getchar() -> char: ax */
	.text
getchar:
	push	bx
	test	(istr), -1			/* from str */
	je	1f
	mov	bx, (istr)
	inc	(istr)
	mov	al, (bx)
	test	al, al
	jne	9f
	mov	(istr), 0
1:	test	(inum), -1			/* from int */
	je	1f
	mov	ax, (inum)
	shl	(inum), 4
	shr	ax, 12
	mov	bx, hexmap
	xlat
	j	9f
1:	mov	bx, (ipos)
	cmp	bx, (ilen)
	jl	1f
	test	(ifd), -1			/* from stdin */
	jne	2f
	mov	(0f), greeting
	cmp	si, argbuf
	je	3f
	mov	(0f), continue
3:	mov	bx, 1
	sys	write; 0:..; 3
2:	mov	bx, (ifd)			/* from file */
	sys	read; ibuf; 512
	cmp	ax, 0
	ja	4f
	sys	exit; 0
4:	xor	bx, bx
	mov	(ilen), ax
	mov	(ipos), bx
1:	mov	al, ibuf(bx)
	inc	(ipos)
9:	cbw
	pop	bx
	ret
	.data
hexmap: <0123456789abcdef>
greeting: <i: >
continue: <.. >
	.bss
istr: .=.+2					/* input from string */
inum: .=.+2					/* input from int */
ifd: .=.+2					/* input from file */
ibuf: .=.+512
ipos: .=.+2
ilen: .=.+2


/* - store_char(argv: di, *argv: si, char: al) { ax } */
	.bss
cstate: .=.+1
	.text
store_char:
	mov	(si), al
	inc	si
	testb	(cstate), -1
	jne	1f
	incb	(cstate)
	lea	ax, -1(si)
	stosw
	inc	(argc)
1:	ret

/* - parse() -> argbuf */
	.text
parse:
	movb	(argc), 0
	mov	si, argbuf
	mov	di, argv
	mov	ax, si
1:	call	getchar
	mov	bx, ax
	shl	bx, 1
	call	ctab(bx)
	j	1b
.esc:	call	getchar				/* \ */
.def:	j	store_char
.com:	call	getchar				/* # */
	cmp	al, '\n
	jne	.com
.end:	mov	(di), 0				/* \n ; */
	mov	bx, (ipos)
	sub	bx, (ilen)			/* clear cache */
	mov	(0f), bx
	push	(ilen)
	pop	(ipos)
	mov	bx, (ifd)
	sys	seek; 0: 0; 1
	pop	ax				/* skip return */
.tab:	movb	(cstate), 0			/* \s \t */
	movb	(si), '\0
	inc	si
.unk:	ret					/* unknown */
.dol:	call	getchar				/* $ */
	cmp	al, '#
	jne	1f
	push	(this_argc)
	pop	(inum)
	ret
1:	cmp	al, '?
	jne	1f
	sys	wait
	mov	(inum), ax
1:	mov	bx, (_argvp)
	sub	ax, '0-1
	shl	ax, 1
	add	bx, ax
	push	(bx)
	pop	(istr)
	ret
.str:	call	getchar
	cmp	al, '"
	je	.unk
	push	.str
	jmp	store_char
.io0:
.io1:
	.data
ctab:	.unk; .unk; .unk; .unk; .unk; .unk; .unk; .unk
	.unk; .tab; .end; .unk; .unk; .unk; .unk; .unk
	.unk; .unk; .unk; .unk; .unk; .unk; .unk; .unk
	.unk; .unk; .unk; .unk; .unk; .unk; .unk; .unk
	.tab; .def; .str; .com; .dol; .def; .def; .def
	.def; .def; .def; .def; .def; .def; .def; .def
	.def; .def; .def; .def; .def; .def; .def; .def
	.def; .def; .def; .end; .io0; .def; .io1; .def
	.def; .def; .def; .def; .def; .def; .def; .def
	.def; .def; .def; .def; .def; .def; .def; .def
	.def; .def; .def; .def; .def; .def; .def; .def
	.def; .def; .def; .def; .esc; .def; .def; .def
	.def; .def; .def; .def; .def; .def; .def; .def
	.def; .def; .def; .def; .def; .def; .def; .def
	.def; .def; .def; .def; .def; .def; .def; .def
	.def; .def; .def; .def; .def; .def; .def; .unk

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


	.bss; end:
