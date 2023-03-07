	.orig	STACK_SIZE
	.text

start:
	mov	di, 2(si)
	mov	si, 4(si)
1:	lodsb
	scasb
	jne	neq
	test	al, al
	jne	1b
	sys	exit; 0
neq:	sys	exit; 1
