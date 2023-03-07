	.orig	STACK_SIZE
	.text

start:
	add	si, 2
	dec	cx
	call	expr
go:	test	dx, dx
	jne	q
skip:	mov	bx, 3
	sys	read; buf; 1
	mov	al, (buf)
	cmp	al, '\n
	je	q
	cmp	al, ';
	jne	skip
q:	sys	exit; 0

error:	mov	bx, 2
	sys	write; 0f; 9
	sys	exit; 1
0:	<if error\n>

1:	pop	ax
	ret
mnext:	jcxz	1b
next:	jcxz	error
	lodsw
	mov	di, ax
	dec	cx
	ret

eq:	pop	bx
	mov	ax, (bx)
	add	bx, 2
	cmp	ax, (di)
	jne	9f
	testb	2(di), -1
9:	jmp	bx

/* compare dx and di */
streq:	push	di
	push	si
	mov	si, dx
1:	lodsb
	scasb
	jne	2f
	test	al, al
	jne	1b
2:	pop	si
	pop	di
	ret

expr:
e1:	
	call	e2
	call	mnext
	call	eq; <-o>
	bne	error
	push	dx
	call	expr
	pop	ax
	or	dx, ax
	ret

e2:	call	e3
	call	mnext
	call	eq; <-a>
	bne	error
	push	dx
	call	expr
	pop	ax
	and	dx, ax
	ret

e3:	call	next
	cmp	(di), '!
	jne	e4
	call	expr
not_dx:
	test	dx, dx
set_flag:
	sete	al
	cbw
	mov	dx, ax
	ret

e4:
e4.1:	call	eq; <-z>
	jne	e4.2
	call	next
	call	eq; <[]>
	j	set_flag
e4.2:	call	eq; <-0>
	jne	e4.3
	call	next
	cmp	(di), '0
	j	set_flag
e4.3:
e4.4:
e4.5:	mov	dx, di
	call	next
	call	eq; <==>
	jne	e4.6
	call	next
	call	streq
	j	set_flag
e4.6:	call	eq; <!=>
	jne	e4.7
	call	next
	call	streq
	call	set_flag
	j	not_dx

e4.7:	jmp	error

buf:..
