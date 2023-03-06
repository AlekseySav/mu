/*
 * list files
 */
	.orig	STACK_SIZE
	.text

start:
	sys	brk; end
	cmp	cx, 2
	jne	2f
	push	2(si)
	pop	(0f)
2:	sys	open; 0: dot; 0
	mov	bx, ax
	movb	(pad), '\s
1:	sys	read; buf; 16
	cmp	ax, 0
	jle	quit
	test	(buf), -1
	je	1b
	testb	(name), -1
	je	1b
	cmpb	(name), '.
	je	1b
	push	bx
	mov	bx, 1
	sys	write; name; 16
	pop	bx
	j	1b
quit:	
	sys	close
	mov	bx, 1
	sys	write; lf; 1
	sys	exit

dot:	<.\0>
lf:	<\n>
	.bss
buf: .=.+2
name: .=.+14
pad: .=.+1
end:
