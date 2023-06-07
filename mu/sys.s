/ all syscalls implementation

	.sect	<.text>

sys.rele:
	movb	$0, p.counter(di)
	jmp	sched

sys.exit:
	cmp	$1, p.id(di)
	je	error
	movb	$-1, p.state(di)
	mov	bx, p.ax(di)
	mov	p.parent(di), bx
	mov	bx, current
	call	proc.child
	jmp	sched

sys.fork:
	mov	current, bx
	call	proc.create
	mov	p.break(bx), dx
	xchg	current, bx
	call	proc.copy
	mov	ax, p.seg(bx)
	mov	current, di
	mov	p.break(di), ax
	mov	ax, p.break(bx)
	mov	p.pwd(di), ax
	mov	ax, p.pwd(bx)
	mov	p.ttyp(di), ax
	mov	ax, p.ttyp(bx)
	mov	p.sp(di), ax
	mov	ax, p.sp(bx)
	mov	p.id(bx), ax
	mov	ax, p.ax(di)
	ret

sys.read:
	call	fp.get
	testb	$-1, f.mode(bx)
	jne	error
	call	fp.read
	mov	ax, p.ax(di)
	ret

sys.write:
	call	fp.get
	testb	$-1, f.mode(bx)
	je	error
	call	fp.write
	mov	ax, p.ax(di)
	ret

sys.open:
	mov	si, cx				/ mode
	mov	bx, si
	call	namei_c
	push	dx
	call	fp.close
	pop	ax
	call	fp.openi
	mov	cl, f.mode(bx)
	call	proc.fd
	mov	ax, p.ax(di)
	ret

sys.close:
	push	bx
	call	fp.get
	call	fp.close
	pop	bx
seg fs; mov	(bx), bx
	shl	$1, bx
	mov	$0, p.fd(bx,di)
	ret

sys.wait:
	mov	$proc, si
	mov	$N_PROC, cx
1:	cmpb	$0, p.state(si)
	jae	2f
	cmp	di, p.parent(si)
	jne	2f
	mov	p.ax(si), ax			/ dead child found
	mov	ax, p.ax(di)
	mov	si, current
	call	proc.delete
	mov	di, current
	ret
2:	add	$proc_size, si
	loop	1b
	movb	$WAIT_CHILD, p.state(di)
	jmp	sched

sys.intr:
	test	$!1, bx
	jne	error
	inc	bx
	and	$1, bl				/ 1->0, 0->1
	andb	$!1, p.flags(di)
	or	bl, p.flags(di)
	ret

sys.sttyp:
	test	bx, bx
	je	error
	cmp	$8, bx
	jae	error
	shl	$tty_log, bx
	add	$tty, bx
	mov	bx, p.ttyp(di)
	ret

sys.getpid:
	mov	p.id(di), ax
	mov	ax, p.ax(di)
	ret

sys.getppid:
	mov	p.parent(di), bx
	mov	p.id(bx), ax
	mov	ax, p.ax(di)
	ret

sys.brk:
	add	$511, bx
	shr	$9, bx
	cmp	$3, bx
	jb	9f
	cmp	p.break(di), bx
	jbe	9f
	mov	bx, dx
	call	proc.copy
	xchg	p.seg(di), ax
	xchg	p.break(di), bx
	mov	bx, dx
	call	mm.free
9:	mov	p.break(di), bx
	shl	$9, bx
	mov	bx, p.ax(di)
	ret

sys.dup:
	call	fp.get
	incb	f.links(bx)
	call	proc.fd
	mov	ax, p.ax(di)
	ret

/ sys.unlink:
/ 	call	namei_c
/ 	mov	$0, (si)			/ unlink name
/ 	call	fp.close
/ 	mov	di, bx
/ 	lea	p.inum(bx), di
/ 	call	iget
/ 	dec	i.links(di)
/ 	jne	9f
/ 	movb	$0, i.flags(di)
/ 9:	lea	p.inum(bx), di
/ 	jmp	buf.free

/ syscreat
/ syslink
/ sysunlink
/ sysexec
/ syschdir

	.sect	<.data>

systable:
	0; sys.rele
	1; sys.exit
	0; sys.fork
	3; sys.read
	3; sys.write
	2; sys.open
	1; sys.close
	0; sys.wait
	1; sys.intr
	1; sys.sttyp
	0; sys.getpid
	0; sys.getppid
	1; sys.brk
	1; sys.dup

n_syscalls = [.-systable]/4
