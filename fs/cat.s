	.orig	STACK_SIZE
	.text

start:
	sys	brk; end
	cmp	cx, 1
	ja	1f
	call	echo				/* from stdin */
9:	sys	exit
1:	lodsw
1:	lodsw					/* from files */
	test	ax, ax
	je	9b
	mov	(0f), ax
	sys	open; 0:..; 0
	test	ax, ax
	js	error
	mov	cx, ax
	push	ax
	call	echo
	pop	bx
	sys	close
	j	1b

echo:
	mov	bx, cx
	sys	read; buf; 512
	test	ax, ax
	jne	1f
	ret
1:	mov	(0f), ax
	mov	bx, 1
	sys	write; buf; 0:..
	j	echo

error:
	mov	bx, 2
	sys	write; errbuf; errlen
	sys	exit

	.data
errbuf: <cat error\n>
errlen = .-errbuf

	.bss
buf: .=.+512
	end:
