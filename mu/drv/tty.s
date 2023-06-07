/ tty driver -- provide tty interface for char devices
/ tty.init()
/ tty.read(inode: bx, buf: fs:si, n: cx)	{ ax, cx, dx, bx }
/ tty.write(inode: bx, buf: fs:si, n: cx)	{ ax, cx, dx, bx }
/
/ tty.poll(inode: bx, char: al)			{ ax, dx, bx }
/
/ tty.flush(tty: bx)				{ ax, dx }
/ tty.put(tty: bx, char: al)			{ ax, dx }
/

	.sect	<.init>

tty.init:
	mov	$IEOF, tty+1*tty_size
	mov	$ICANON|ISIG|ECHO|ECHOE|IVERIFY|INOTAB, tty+2*tty_size
	mov	$ICANON|ECHO|ONLCR|ICRNL|INOTAB, tty+3*tty_size
	ret

 	.sect	<.text>

sleep_on_tty:
	push	fs
	pusha
	mov	current, di
	orb	$WAIT_TTY, p.state(di)
	mov	sp, p.sp2(di)
	incb	tty.n_sleeps(bx)
	call	sched
	jmp	return

wake_on_tty:
	push	di
	testb	$-1, tty.n_sleeps(bx)
	je	9f
	decb	tty.n_sleeps(bx)
	mov	$proc-proc_size, di
1:	add	$proc_size, di
	cmp	p.ttyp(di), bx
	jne	1b
	testb	$WAIT_TTY, p.state(di)
	je	1b
	andb	$!WAIT_TTY, p.state(di)
	orb	$PF_SYS, p.flags(di)
9:	pop	di
	ret

tty.read:
	shl	$tty_log, bx
	add	$tty, bx
1:	testb	$-1, tty.line(bx)
	jne	1f
	push	$1b
	jmp	sleep_on_tty
1:	dec	tty.line(bx)
	test	$IEOF, tty.mode(bx)
	jne	9f
	push	di
	push	si
	push	bp
	lea	tty.buf(bx), di
	call	buf.mmap1
	mov	tty.head(bx), bp
1:	seg	ds
	mov	(bp,di), al
	inc	bp
	and	$511, bp
	seg	fs
	mov	al, (si)
	inc	si
	cmp	$'\n, al
	jne	3f
	dec	cx
	jmp	2f
3:	loop	1b
2:	mov	bp, tty.head(bx)
	pop	bp
	pop	si
	pop	di
9:	ret

tty.write:
	shl	$tty_log, bx
	add	$tty, bx
1:	seg	fs
	lodsb
	call	tty.put
	loop	1b
	call	tty.flush
	ret

tty.poll:
	shl	$tty_log, bx
	add	$tty, bx
	and	$!IEOF, tty.mode(bx)		/ new char => undo (eof)
 	push	di
	test	$IVERIFY, tty.mode(bx)
	je	1f
	test	al, al
	js	9f
1:	push	$9f
	cmp	$'\d, al
	je	cc.del
	cmp	$'\s, al
	jae	cc.put
	push	ax
	push	bx
	mov	$tty_c_cc, bx
	xlat
	xor	ah, ah
	add	$0f, ax
	mov	ax, dx
	pop	bx
	pop	ax
	jmp	dx
9:	pop	di
	ret

0:
cc.tab:	test	$INOTAB, tty.mode(bx)
	jne	cc.nop
	je	cc.put
cc.ret:	test	$ICRNL, tty.mode(bx)
	je	cc.clf
	mov	$'\n, al
cc.clf:	inc	tty.line(bx)
	call	wake_on_tty
cc.put:	lea	tty.buf(bx), di
	call	buf.mmap1
	add	tty.tail(bx), di
	stosb
	inc	tty.tail(bx)
	and	$511, tty.tail(bx)
	call	tty.put
8:	jmp	tty.flush
cc.int:	incb	tty.intr(bx)
cc.nop:	test	$ECHOE, tty.mode(bx)
	je	9f
	push	ax
	call	cc.kil
	mov	$'^, al
	call	tty.put
	pop	ax
	add	$'@, al
	call	tty.put
	jmp	tty.flush
cc.eof:	mov	tty.head(bx), ax
	cmp	tty.tail(bx), ax
	jne	cc.nop				/ line not empty
	or	$IEOF, tty.mode(bx)
	inc	tty.line(bx)
9:	ret	
cc.del:	mov	tty.head(bx), ax		/ delete char
	cmp	tty.tail(bx), ax
	je	9b
	dec	tty.tail(bx)
	and	$511, tty.tail(bx)
	call	tty.put_del
	jmp	tty.flush
cc.kil:	mov	$0, tty.line(bx)
	mov	tty.head(bx), ax		/ delete all
	cmp	tty.tail(bx), ax
	je	tty.flush
	inc	tty.head(bx)
	and	$511, tty.head(bx)
	call	tty.put_del
	jmp	cc.kil
cc.wrd:	mov	tty.head(bx), ax		/ delete word
	cmp	tty.tail(bx), ax
	je	tty.flush
	dec	tty.tail(bx)
	and	$511, tty.tail(bx)
	lea	tty.buf(bx), di
	call	buf.mmap1
	add	tty.tail(bx), di
	mov	(di), al
	cmp	$'\s, al
	je	1f
	cmp	$'\t, al
	je	1f
	cmp	$'\n, al
	je	1f
	call	tty.put_del
	jmp	cc.wrd
1:	inc	tty.tail(bx)
	and	$511, tty.tail(bx)
	jmp	tty.flush

	.sect	<.data>

tty_c_cc:
	.byte	cc.nop-0b, cc.int-0b, cc.nop-0b, cc.int-0b
	.byte	cc.eof-0b, cc.nop-0b, cc.nop-0b, cc.nop-0b
	.byte	cc.del-0b, cc.tab-0b, cc.clf-0b, cc.nop-0b
	.byte	cc.nop-0b, cc.ret-0b, cc.nop-0b, cc.nop-0b
	.byte	cc.nop-0b, cc.nop-0b, cc.nop-0b, cc.nop-0b
	.byte	cc.nop-0b, cc.kil-0b, cc.nop-0b, cc.wrd-0b
	.byte	cc.nop-0b, cc.nop-0b, cc.nop-0b, cc.nop-0b
	.byte	cc.nop-0b, cc.nop-0b, cc.nop-0b, cc.nop-0b

	.sect	<.text>

null.put:					/ /dev/null
	xor	cx, cx				/ trick tty.write
idlefunc:
	ret

tty.flush:
	cmp	$tty+2*tty_size, bx
	je	con.flush
	ret

tty.put_del:
	mov	$'\b, al
tty.put:
	push	bx
	sub	$tty, bx
	shr	$tty_log-1, bx
	mov	tty.mode(bx), dx
	cmp	$'\n, al
	jne	1f
	test	$ONLCR, dx
	je	1f
	mov	$'\r, al
	call	5f-2(bx)
	mov	$'\n, al
1:	call	5f-2(bx)
	pop	bx
	ret

	.sect	<.data>

5:	null.put
	con.put
	rs1.put
	rs2.put
	error
	error
	error

 	.sect	<.bss>

tty = .-tty_size
	.=.+tty_size*7
