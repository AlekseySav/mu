/ fsp table & basic tools
/ fp.get(fd: bx) -> fp: bx
/ fp.openi(inode: ax) -> fp: bx			{ ax, dx }
/ fp.close(fp: bx)				{ ax, dx }
/ fp.read(fp: bx, buf: fs:si, n: cx) -> n: ax	{ dx }
/ fp.write(fp: bx, buf: fs:si, n: cx) -> n: ax	{ dx }
/

	.sect	<.text>

fp.get:
seg fs; mov	(bx), bx
	cmp	$N_OPEN, bx
	jae	error
	push	di
	mov	current, di
	shl	$1, bx
	mov	p.fd(bx,di), bx
	pop	di
	test	bx, bx
	je	error
	ret

fp.openi:
	mov	$fsp, bx
1:	cmp	$fsp+fp_size*N_OPEN, bx
	je	error
	testb	$-1, f.links(bx)
	je	1f
	add	$fp_size, bx
	jmp	1b
1:	mov	ax, f.inum(bx)
	cmp	$8, ax
	jb	1f
	call	openi
1:	incb	f.links(bx)
	movb	$0, f.mode(bx)
	movl	$0, f.pos(bx)
	ret

fp.close:
	dec	f.links(bx)
	jne	9f
	push	di
	lea	f.buf(bx), di
/ TEMPORARY (!!!)
mov $0, (di)
	call	buf.free
	lea	f.xzones(bx), di
	call	buf.free
	lea	f.inode(bx), di
	call	buf.free
	movb	$0, f.inum(bx)
	pop	di
9:	ret

fp.read:
	push	di
	mov	$7f, di
	jmp	1f
fp.write:
	push	di
	mov	$8f, di
1:	mov	f.inum(bx), al
	cmp	$8, al
	jae	1f
	cbw
	push	bx
	push	cx
	push	cx
	mov	ax, bx
	call	(di)
	pop	ax
	sub	cx, ax
	pop	cx
	pop	bx
	pop	di
1:	/ call 2(di)
	ret

	.sect	<.data>

7:	tty.read; ..
8:	tty.write; ..

	.sect	<.bss>

.fsp: / for debug only
fsp:	.=.+N_OPEN*fp_size
