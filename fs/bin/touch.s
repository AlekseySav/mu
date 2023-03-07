	.orig	STACK_SIZE
	.text

start:
	push	2(si)
	pop	(0f)
	cmp	cx, 3
	jne	1f
	//push	4(si)
	//pop	(1f)
1:	sys	creat; 0:..; 1: 6
	sys	exit; 0
