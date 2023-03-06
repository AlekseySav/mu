/*
 * clear screen
 */
	.orig	STACK_SIZE
	.text

start:
	push	es
	push	0xb800
	pop	es
	xor	di, di
	mov	cx, 80*25
	mov	ax, 0x0720
	rep stosw
	pop	es
	sys	stty; tty
	sys	exit
tty:	0; 0xb800; 0x07
