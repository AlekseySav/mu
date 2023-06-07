/ process manager
/ proc.create() -> current			{ ax, dx }
/ proc.delete(current) -> current=p.parent	{ ax, dx }
/ proc.copy(current, break: dx) -> seg: ax	{ dx }
/ proc.fd(current, fp: bx) -> fd: ax		{ dx }
/ proc.child(current, child: di)

	.sect	<.text>

proc.create:
	push	bx
	push	si
	push	di
	push	cx
	mov	$N_PROC, cx			/ find process
	mov	$proc, di
	xor	ax, ax
1:	scasw					/ id = 0 ?
	je	1f
	add	$proc_size-2, di
	loop	1b
	jmp	error
1:	mov	$[proc_size-2]/2, cx
	rep stosw				/ clear process
	sub	$proc_size, di
	inc	uuid
	push	uuid
	pop	p.id(di)			/ assign id
	mov	current, si
	mov	si, p.parent(di)
	mov	di, current
	test	si, si
	je	9f
	add	$p.fd, si
	add	$p.fd, di
	mov	$N_OPEN, cx
1:	lodsw
	stosw
	test	ax, ax
	je	2f
	mov	ax, bx
	incb	f.links(bx)
2:	loop	1b
9:	pop	cx
	pop	di
	pop	si
	pop	bx
	ret

proc.delete:
	push	si
	push	di
	push	cx
	push	bx
	mov	current, di
	mov	p.parent(di), ax
	mov	ax, current
	lea	p.fd(di), si			/ close files
	mov	$N_OPEN, cx
1:	lodsw
	test	ax, ax
	je	8f
	mov	ax, bx
	call	fp.close
8:	loop	1b
	mov	$0, p.id(di)
	pop	bx
	pop	cx
	pop	di
	pop	si
	ret

/ copy user data only, used by sys.brk, sys.fork, sys.exec
proc.copy:
	push	bx
	push	cx
	push	si
	push	di
	push	ds
	push	es
	mov	current, bx
	call	mm.alloc
	mov	ax, es
	mov	p.break(bx), cx
	mov	p.seg(bx), ds
	shl	$8, cx
	xor	si, si
	xor	di, di
	rep movsw
	mov	es, ax
	pop	es
	pop	ds
	pop	di
	pop	si
	pop	cx
	pop	bx
	ret

proc.fd:
	push	di
	push	cx
	mov	current, di
	add	$p.fd, di
	mov	$N_OPEN, cx
	xor	ax, ax
	repne scasw
	je	1f
	call	fp.close
	jmp	error
1:	mov	bx, -2(di)
	mov	$N_OPEN-1, ax
	sub	cx, ax
	pop	cx
	pop	di
	ret

proc.child:
	push	bx
	mov	current, bx
	decb	p.childs(bx)
	testb	$0x80, p.state(bx)
	je	1f
	testb	$-1, p.childs(bx)
	jne	9f
	movb	$0, p.state(bx)
	pop	bx
	ret
1:	testb	$WAIT_CHILD, p.state(bx)
	je	9f
	mov	p.ax(di), ax
	mov	ax, p.ax(bx)
	movb	$0, p.state(bx)
	mov	di, current
	call	proc.delete
	mov	bx, current
9:	pop	bx
	ret

	.sect	<.bss>

proc: .=.+N_PROC*proc_size
current: .=.+2
uuid: .=.+2
