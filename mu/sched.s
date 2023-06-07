/ scheduler
/ sched() -> current

	.sect	<.text>

sched:
	push	ax
	push	dx
	push	bx
	push	cx
	push	di
	xor	al, al
	/ find ready process
4:	mov	$proc, bx
	mov	$N_PROC, cx
1:	test	$-1, p.id(bx)			/ exists?
	je	2f
	call	intract
	testb	$-1, p.state(bx)		/ runnable?
	jne	2f
	testb	$-1, p.counter(bx)
	jne	3f				/ proc found
2:	add	$proc_size, bx
	loop	1b
	/ no ready process, adjust counters
	mov	$proc, bx
	mov	$N_PROC, cx
1:	test	$-1, p.id(bx)			/ exists?
	je	2f
	testb	$-1, p.state(bx)		/ runnable?
	jne	2f
	addb	$15, p.counter(bx)
2:	add	$proc_size, bx
	loop	1b
	jmp	4b
3:	mov	bx, current
	pop	di
	pop	cx
	pop	bx
	pop	dx
	pop	ax
	ret

intract:
	mov	p.ttyp(bx), di
	test	di, di
	je	9f
	testb	$-1, tty.intr(di)
	je	9f
	testb	$PF_INTR, p.flags(bx)
	jne	9f
	testb	$WAIT_CHILD, p.state(bx)
	jne	9f
	decb	tty.intr(di)
	orb	$0x80, p.state(bx)
	mov	p.parent(bx), di
	mov	di, current
	mov	bx, di
	call	proc.child
9:	ret
