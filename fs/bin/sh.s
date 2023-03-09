	.orig	STACK_SIZE
	.text

start:
	sys	brk; end
	mov	(this_argc), cx
	jcxz	command
	push	(si)
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
	dec	(this_argc)
	j	command
1:	sys	fork
	test	ax, ax
	je	1f
	xor	di, di
	call	reset_fd
	mov	di, 1
	call	reset_fd
	j	command
1:	push	(argv)				/* check if shell script */
	pop	(0f)
	sys	open; 0:..; 0
	mov	bx, ax
	sys	read; buf2; 2
	sys	close
	cmp	(buf2), '#|['!*256]
	jne	1f
	sys	exec; shell; argv
1:	call	do_exec				/* try ./ */
	sub	(argv), 5
	mov	di, (argv)
	mov	si, bin
	mov	cx, 5
	rep movsb
	call	do_exec				/* try /bin/ */
quit:	sys	exit; 0
	.data
shell: </bin/sh\0>
bin: </bin/>
_argvp: argvp


	.bss
this_argc: .=.+2
prefix: .=.+20
argbuf: .=.+512
argv: .=.+100
argc: .=.+2
state: .=.+2
fd_0: .=.+2
fd_1: .=.+2
buf2: .=.+2

/* - queue_number(number: ax) { dx } */
	.text
queue_number:
	push	di
	mov	di, 0f
	std
1:	xor	dx, dx
	div	(base)
	xchg	ax, dx
	add	al, '0
	stosb
	mov	ax, dx
	test	ax, ax
	jne	1b
	cld
	inc	di
	mov	(istr), di
	pop	di
	ret
	.data
base: 10
	.bss
number_buf: .=.+18
0: .=.+2

/* - _getchar() -> char: ax */
	.text
_getchar:
	testb	(peekc), -1			/* was unget? */
	je	1f
	mov	al, (peekc)
	movb	(peekc), 0
	ret
1:	push	bx
	test	(istr), -1			/* from str */
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
9:	ret
	.data
greeting: <i: >
continue: <.. >
	.bss
istr: .=.+2					/* input from string */
ifd: .=.+2					/* input from file */
ibuf: .=.+512
ipos: .=.+2
ilen: .=.+2
peekc: .=.+1

/* - getchar() -> char: ax */
	.text
getchar:
	call	_getchar
	cmp	al, '$
	jne	9b
	call	getchar
	cmp	al, '#
	jne	1f
	mov	ax, (this_argc)
	call	queue_number
	jmp	getchar
1:	cmp	al, '?
	jne	1f
	sys	wait
	call	queue_number
	jmp	getchar
1:	mov	bx, (_argvp)
	sub	ax, '0
	shl	ax, 1
	add	bx, ax
	push	(bx)
	pop	(istr)
9:	jmp	getchar

/* - get_filename() -> */
	.text
get_filename:
	push	di
	mov	di, filebuf
1:	call	getchar
	cmp	al, '\s
	je	2f
	cmp	al, '\n
	je	2f
	stosb
	j	1b
2:	mov	(peekc), al
	xor	al, al
	stosb
	pop	di
	ret
	.bss
filebuf: .=.+15


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
.esc:	call	_getchar			/* \ */
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
.str:	call	getchar
	cmp	al, '"
	je	.unk
	cmp	al, '\\
	jne	1f
	call	_getchar
1:	push	.str
	jmp	store_char
.io0:	call	get_filename
	xor	bx, bx
	sys	dup
	mov	(fd_0), ax
	sys	close
	sys	open; filebuf; 0
	ret
.io1:	call	get_filename
	mov	bx, 1
	sys	dup
	mov	(fd_1), ax
	sys	close
	sys	creat; filebuf; 6
	ret
	.data
ctab:	.unk; .unk; .unk; .unk; .unk; .unk; .unk; .unk
	.unk; .tab; .end; .unk; .unk; .unk; .unk; .unk
	.unk; .unk; .unk; .unk; .unk; .unk; .unk; .unk
	.unk; .unk; .unk; .unk; .unk; .unk; .unk; .unk
	.tab; .def; .str; .com; .def; .def; .def; .def
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

/* - reset_fd(&fd: di) */
reset_fd:
	mov	(0f), di
	shl	di, 1
	test	fd_0(di), -1
	je	1f
	mov	bx, fd_0(di)
	sys	dup2; 0:..
	sys	close
	mov	fd_0(di), 0
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


	.bss; end:
