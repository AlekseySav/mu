/*
 * default register usage conventions:
 *
 * df=0
 * ss=es=ds=cs
 *
 * userseg: fs
 * arg1: si
 * arg2: cx
 * fp: bx
 * inode: di
 * process: bp
 *
 * ax, dx -- always free to use
 */

BEGIN_BREAK = 0x1000
END_BREAK = 0x6000
BEGIN_BUFFERS = 0x6000
END_BUFFERS = 0x8000
N_BUFFERS = [END_BUFFERS-BEGIN_BUFFERS]/512*16

	.orig KERNEL_OFFSET
	.bss
bss_start:
memory_map: 	.=.+[N_BUFFERS/8]
fsp:		.=.+[N_FSP*fp_size]
proc:		.=.+[N_PROC*proc_size]
current:	.=.+2

	.text
	jmp	init

/*
 * memory driver
 */

/* - _alloc(map: ds:si, count: cx) -> n: ax 	{ cx, si } */
	.text
_alloc:	push	dx
	mov	dx, cx
1:	lodsw
	cmp	ax, -1
	jne	2f
	loop	1b
	jmp	error
2:	neg	cx
	add	cx, dx
	push	cx
	sub	si, 2
	not	ax
	bsf	cx, ax				/* bit scan */
	mov	ax, 1
	shl	ax, cl
	or	(si), ax			/* mark entry as used */
	pop	ax
	shl	ax, 4
	add	ax, cx				/* ax*16+cx = entry */
	pop	dx
	ret

/* - _free(map: ds:si, count: cx, n: ax) 	{ cx } */
	.text
_free:	cmp	ax, cx
	bhis	error
	push	bx
	mov	bx, ax
	shr	bx, 4
	shl	bx, 1
	mov	cx, ax
	and	cx, 15
	mov	ax, 1
	shl	ax, cl
	not	ax
	and	(bx_si), ax
	pop	bx
	ret


/* - alloc_buffer() -> ptr: ax */
	.text
alloc_buffer:
	push	si
	push	cx
	mov	cx, N_BUFFERS/16
	mov	si, memory_map
	call	_alloc
	shl	ax, 9-4
	add	ax, BEGIN_BUFFERS
	pop	cx
	pop	si
	ret

/* - free_buffer(ptr: ax)			{ ax } */
	.text
free_buffer:
	test	ax, ax
	je	1f
	push	cx
	push	si
	sub	ax, BEGIN_BUFFERS
	shr	ax, 9-4
	mov	cx, N_BUFFERS
	mov	si, memory_map
	call	_free
	pop	si
	pop	cx
1:	ret


/* - adjust_break(size: ax) -> real-size: cx	{ ax } */
	.text
_adjust_break:
	add	ax, 15
	mov	cx, ax
	and	cx, 0xfff0
	shr	ax, 4				/* bytes -> segments */
	add	ax, (break_end)
	cmp	ax, END_BREAK
	bho	error
	mov	(break_end), ax
	ret

/* - adjust_break(size: ax)			{ ax } */
adjust_break:
	push	di
	push	cx
	push	es
	mov	es, (break_end)
	call	_adjust_break
	shr	cx, 1				/* bytes -> words */
	xor	di, di
	xor	ax, ax
	rep stosw
	pop	es
	pop	cx
	pop	di
	ret
	.data
break_end: BEGIN_BREAK


/*
 * disk driver
 */

/* - alloc_zone() -> n: ax */
	.text
alloc_zone:
	push	si
	push	cx
	mov	cx, N_ZONES
	mov	si, d.zone_map
	call	_alloc
	pop	cx
	pop	si
	ret

/* - free_zone(n: ax) 				{ ax } */
	.text
free_zone:
	push	si
	push	cx
	mov	cx, N_ZONES
	mov	si, d.zone_map
	call	_free
	pop	cx
	pop	si
	ret


/* - alloc_inode() -> n: ax */
	.text
alloc_inode:
	push	si
	push	cx
	mov	cx, N_INODES
	mov	si, d.inode_map
	call	_alloc
	pop	cx
	pop	si
	ret

/* - free_inode(n: ax) 				{ ax } */
	.text
free_inode:
	push	si
	push	cx
	mov	cx, N_INODES
	mov	si, d.inode_map
	call	_free
	pop	cx
	pop	si
	ret


/* - read/write_zone(zone: ax, buffer: dx:0) 	{ tmp: using bios } */
	.text
disk_mode: ..
dev: ..
heads: ..
sectors: ..
setup_disk:
	mov	ah, 8
	mov	(dev), dl
	int	0x13
	jc	.
	inc	dh
	mov	(heads), dh
	and	cl, 0x3f
	mov	(sectors), cl
	ret
read_zone:
	mov	(disk_mode), 0x0201
	j	0f
write_zone:
	mov	(disk_mode), 0x0301
0:	pusha
	push	es
	mov	es, dx
	xor	bx, bx
	xor	dx, dx
	div	(sectors)			/* ax = cyl x head, dx = sector - 1 */
	mov	cl, dl
	inc	cl				/* cl = sector */
	divb	(heads)				/* al = cylinder, ah = head */
	mov	dh, ah
	mov	ch, al
	mov	dl, (dev)
	mov	ax, (disk_mode)
	int	0x13
	jc	.
	pop	es
	popa
	ret



/* - sys.sync */
sys.sync:
	mov	cx, disk_size/512-UNMAPPED_ZONES
	mov	ax, UNMAPPED_ZONES
	mov	dx, UNMAPPED_ZONES*512/16
1:	call	write_zone
				//call t_printn
	inc	ax
	add	dx, 512/16
	loop	1b
	ret


/*
 * keyboard driver
 */

/* - keyboard_interrupt */
	.text
keyboard_interrupt:
	cld
	push	ds
	push	es
	push	fs
	pusha
	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	inb	0x60
	mov	dl, al
	and	ax, 0x7f
	cmp	al, kb.count
	jge	0f
	mov	bx, ax
	mov	si, kb.action(bx)
	and	si, 0xff
	add	si, kb.actions
	mov	bx, (kb.state)
	mov	bx, kb.table(bx)
	xlat
	call	si
0:	mov	al, 0x20
	outb	0x20
	popa
	pop	fs
	pop	es
	pop	ds
	iret
kb.actions:
1:	test	dl, dl				/* put char */
	js	0f
6:	mov	si, (kb.tail)
	inc	(kb.tail)
4:	and	(kb.tail), TTY_SIZE-1
	add	si, kb.queue
	mov	(si), al
	mov	cx, 1
	jmp	tty._write
3:	test	dl, dl				/* backspace */
	js	0f
	mov	si, (kb.tail)
	cmp	si, (kb.head)
	je	0f
	add	(kb.tail), TTY_SIZE-1
	j	4b
5:	test	dl, dl				/* new line */
	js	0f
	call	6b
	push	(kb.tail)
	pop	(kb.cooked)
	ret
2:	mov	cl, al				/* ctrl, shift */
	and	cl, 0x7f
	mov	al, 1
	shl	al, cl
	orb	(kb.state), al
	test	dl, dl
	jns	0f
	not	al
	andb	(kb.state), al
0:	ret					/* unknown */
kb.no = 0b-kb.actions
kb.ch = 1b-kb.actions
kb.md = 2b-kb.actions
kb.bs = 3b-kb.actions
kb.lf = 5b-kb.actions
	.data
kb.table: 1f; 2f; 3f; 1f
1:	<\0\e1234567890-=\b\t>			/* default */
	<qwertyuiop[]\n>; .byte 0x82
	<asdfghjkl;'`>; .byte 0x81
	<\\zxcvbnm,./>; .byte 0x81
	<*\0 \0>				/* alt capslock unused */
kb.count = .-1b
2:	<\0\e!@#$%^&*()_+\b\t>			/* shift */
	<QWERTYUIOP[]\n>; .byte 0x82
	<ASDFGHJKL:"~>; .byte 0x81
	<\\ZXCVBNM<\>?>; .byte 0x81
	<*\0 \0>
3:	<\0\e1234567890-=\b\t>			/* ctrl */
	<\^Q\^W\^E\^R\^T\^Y\^U\^I\^O\^P\^[\^]\n>; .byte 0x82
	<\^A\^S\^D\^F\^G\^H\^J\^K\^L;'`>; .byte 0x81
	<\^\\^Z\^X\^C\^V\^B\^N\^M,./>; .byte 0x81
	<*\0 \0>
kb.action:
	.byte kb.no, kb.ch			/* line 1 */
	.byte kb.ch, kb.ch, kb.ch, kb.ch, kb.ch
	.byte kb.ch, kb.ch, kb.ch, kb.ch, kb.ch
	.byte kb.ch, kb.ch, kb.bs, kb.ch
	.byte kb.ch, kb.ch, kb.ch, kb.ch, kb.ch	/* line 2 */
	.byte kb.ch, kb.ch, kb.ch, kb.ch, kb.ch
	.byte kb.ch, kb.ch, kb.lf, kb.md
	.byte kb.ch, kb.ch, kb.ch, kb.ch, kb.ch	/* line 3 */
	.byte kb.ch, kb.ch, kb.ch, kb.ch, kb.ch
	.byte kb.ch, kb.ch, kb.md
	.byte kb.ch, kb.ch, kb.ch, kb.ch, kb.ch	/* line 4 */
	.byte kb.ch, kb.ch, kb.ch, kb.ch, kb.ch
	.byte kb.ch, kb.md
	.byte kb.ch, kb.no, kb.ch, kb.no	/* line 5 */
	.bss
kb.state: .=.+2					/* 1=shift, 2=ctrl */
kb.queue: .=.+TTY_SIZE
kb.head: .=.+2
kb.tail: .=.+2
kb.cooked: .=.+2

/*
 * tty driver
 */

/* - out_b(data: al, command: cl, data port: dx, command port: bx) */
	.text
out_b:	cli
	xchg	dx, bx
	xchg	ax, cx
	outb
	xchg	ax, cx
	xchg	dx, bx
	outb
	sti
	ret

/* - out_w(data: ax, command: cx, data port: dx, command port: bx) */
	.text
out_w:	push	ax
	push	cx
	call	out_b
	shr	ax, 8
	shr	cx, 8
	call 	out_b
	pop	cx
	pop	ax
	ret


/* - update_cursor(cursor: ax) 			{ ax, bx, cx, dx } */
update_cursor:
	shr	ax, 1
	mov	cx, 0x0e0f			/* update cursor */
	mov	bx, 0x3d4
	mov	dx, 0x3d5
	jmp	out_w

/* - tty.read(buf: fs:si, cx: n) -> n: p.ax */
	.text
tty.read:
	mov	di, si
	mov	si, (kb.head)
	pushf
1:	sti
	cmp	si, (kb.tail)
	je	1b
	popf
	cmpb	kb.queue(si), '\^D
	jne	1f
	mov	p.ax(bp), 0
	inc	(kb.head)
	and	(kb.head), TTY_SIZE-1
	push	(kb.head)
	pop	(kb.cooked)
	ret
1:	mov	p.ax(bp), cx
	push	fs
	pop	es
	pushf
1:	sti
	cmp	si, (kb.cooked)
	je	1b
	popf
2:	mov	al, kb.queue(si)
	inc	si
	and	si, TTY_SIZE-1
	stosb
	cmp	si, (kb.cooked)
	loopne	2b
	mov	(kb.head), si
	sub	p.ax(bp), cx
	ret

/* - tty.write(buf: fs:si, cx: n) -> n: p.ax 	{ ax, bx, cx, dx, si, di } */
	.text
tty.write:
	mov	p.ax(bp), cx

/* - tty._write(buf: fs:si, cx: n) 		{ ax, bx, cx, dx, si, di } */
tty._write:
	push	es
	les	di, (cursor)
1:	seg	fs
	lodsb
	cmp	al, '\s
	jb	2f
	mov	ah, (attr)
	stosw
3:	loop	1b
	mov	ax, di
	pop	es
	mov	(cursor), ax
	jmp	update_cursor
2:	mov	bx, con.table
	xlat
	cbw
	add	ax, c
	push	3b
	jmp	ax
c:
c.bl:	ret					/* not implemented */
c.bs:	sub	di, 2
	mov	ax, 0x0720
	mov	(es:di), ax
c.no:	ret
c.ht:	add	di, 16
	and	di, 0xfff0
	ret
c.lf:	add	di, 160
c.cr:	mov	ax, di
	divb	(columns)
	xor	al, al
	xchg	al, ah
	sub	di, ax
	ret
c.es:	ret					/* not implemented */
	.data
con.table:
	.byte	c.no-c, c.no-c, c.no-c, c.no-c, c.no-c, c.no-c, c.no-c, c.bl-c
	.byte	c.bs-c, c.ht-c, c.lf-c, c.no-c, c.no-c, c.cr-c, c.no-c, c.no-c
	.byte	c.no-c, c.no-c, c.no-c, c.no-c, c.no-c, c.no-c, c.no-c, c.no-c
	.byte	c.no-c, c.no-c, c.no-c, c.es-c, c.no-c, c.no-c, c.no-c, c.no-c
columns: 160
tty:
cursor:	0; 0xb800
attr: 0x07


/* - sys.gtty */
	.text
sys.gtty:
	mov	di, si
	mov	si, tty
	mov	cx, tty_size/2
	push	es
	push	fs
	pop	es
	rep movsw
	pop	es
	ret

/* - sys.stty */
sys.stty:
	mov	di, tty
	mov	cx, tty_size/2
	rep seg fs movsw
	jmp	update_cursor


/*
 * process manager
 */

/* - sys.getpid */ 
sys.getpid:
	push	p.id(bp)
	pop	p.ax(bp)
	ret

/* - sys.getppid */
sys.getppid:
	mov	di, p.parent(bp)
	push	p.id(di)
	pop	p.ax(bp)
	ret

/* - sys.brk */
sys.brk:
	mov	ax, si
	sub	ax, p.brk(bp)
	jbe	1f
	call	adjust_break
	mov	ax, (break_end)
	sub	ax, p.seg(bp)
	shl	ax, 4
	mov	p.brk(bp), ax
1:	push	p.brk(bp)
	pop	p.ax(bp)
	ret

/* - sys.alloc */
sys.alloc:
	call	alloc_buffer
	mov	p.ax(bp), ax
	ret

/* - sys.free */
sys.free:
	mov	ax, bx
	call	free_buffer
	ret

/* - sys.exit */
sys.exit:
	cmp	p.id(bp), 1
	beq	error				/* prevent init task exit */
	mov	p.id(bp), 0
	push	p.seg(bp)
	pop	(break_end)
	mov	bp, p.parent(bp)
	mov	(current), bp
	ret

/* - sys.fork */
sys.fork:
	call	create_process
	mov	p.ax(bp), ax			/* pid to parent */
	push	(break_end)
	pop	p.seg(di)
	mov	ax, p.brk(bp)
	call	adjust_break			/* memory for child */
	push	p.ax(bp)
	pop	p.id(di)
	mov	p.parent(di), bp
	mov	(current), di
/* p.id, p.parent, p.seg, p.ax set manualy, other data copied from parent */
	push	ds
	push	es
	push	di				/* copy process meta */
	lea	si, p.brk(bp)
	add	di, p.brk
	mov	cx, [proc_size-p.brk]/2
	rep movsw
	mov	ds, p.seg(bp)
	pop	bp				/* bp=child */
	mov	es, p.seg(bp)
	xor	si, si				/* copy process memory */
	xor	di, di
	mov	cx, p.brk(bp)			/* no need for cs:bp :) */
	rep movsb
			//mov ax, p.sp(bp); call t_printn
			//mov bx, p.sp(bp)
			//mov ax, 18(es:bx); call t_printn
	pop	es
	pop	ds
	jmp	reset_segments


/* - create_process() -> proc: di, pid: ax */
0:	mov	cx, N_PROC			/* get proc+2 with pid=ax */
	mov	di, proc
1:	scasw
	je	1f
	add	di, proc_size-2
	loop	1b
1:	test	cx, cx
	ret
create_process:
	push	cx
	xor	ax, ax				/* get free process */
	call	0b
	beq	error
	sub	di, 2
	push	di				/* save process */
1:	inc	ax				/* find unique id */
	call	0b
	jne	1b
	pop	di
	pop	cx
	ret


/*
 * file system
 */

/* - create_fp() -> fp: di	 		{ ax } */
create_fp:
	push	cx
	mov	cx, N_FSP
	mov	di, fsp+f.links
	xor	ax, ax
1:	scasb
	je	1f
	add	di, fp_size-1
	loop	1b
	jmp	error
1:	sub	di, f.links+1
	mov	cx, fp_size/2			/* clear fp */
	rep stosw
	sub	di, fp_size
	pop	cx
	ret

/* - close_fp(fp: bx, inode: di)		{ ax } */
close_fp:
	decb	f.links(bx)
	jne	0f

/* - release_fp(fp: bx, inode: di) 		{ ax } */
release_fp:
	push	dx
	mov	dx, f.xzones(bx)
	testb	f.mode(bx), 1
	je	1f
	call	write_buffer
	test	dx, dx
	je	1f
	mov	ax, i.zones+[9*2](di)
	call	write_zone
1:	mov	ax, dx
	call	free_buffer
	mov	f.xzones(bx), 0
	mov	f.pos(bx), 0
	pop	dx
	call	detach_buffer
0:	ret

/* - create_fd(process: bp, fp: bx) -> fd: p.ax { ax } */
create_fd:
	push	di
	push	cx
	xor	ax, ax
	lea	di, p.fd(bp)
	mov	cx, N_OPEN
	repne scasw
	bne	error
	sub	di, 2
	mov	(di), bx
	neg	cx
	add	cx, N_OPEN-1
	mov	p.ax(bp), cx
	pop	cx
	pop	di
	ret


/* - fetch_xzones(fp: bx, inode: di) 		{ ax } */
fetch_xzones:
	mov	ax, f.xzones(bx)
	test	ax, ax
	jne	1f
	push	dx
	call	alloc_buffer
	mov	dx, ax
	mov	ax, i.zones+[9*2](di)
	call	read_zone
	mov	f.xzones(bx), dx
	pop	dx
1:	ret

/* - get_zone(fp: bx, inode: di) -> zone: ax, empty: ZF */
get_zone:
	push	bp
	mov	bp, f.pos(bx)
	shr	bp, 9
	shl	bp, 1
	cmp	bp, 9*2
	jb	1f
	call	fetch_xzones
	push	ss
	mov	ss, f.xzones(bx)
	sub	bp, 9*2
	mov	ax, 0(bp)
	pop	ss
	j	2f
1:	mov	ax, i.zones(bp_di)
2:	pop	bp
	test	ax, ax
	ret

/* - set_zone(fp: bx, inode: di, zone: ax) */
set_zone:
	push	bp
	mov	bp, f.pos(bx)
	shr	bp, 9
	shl	bp, 1
	cmp	bp, 9*2
	jae	1f
	mov	i.zones(bp_di), ax
	pop	bp
	ret
1:	test	i.zones+[9*2](di), -1
	jne	1f
	push	ax
	call	alloc_zone
	mov	i.zones+[9*2](di), ax
	pop	ax
1:	push	ax
	call	fetch_xzones
	pop	ax
	push	ss
	mov	ss, f.xzones(bx)
	mov	-[9*2](bp), ax
	pop	ss
	pop	bp
	ret


/* - clear_buffer(fp: bx) */
clear_buffer:
	push	ax
	push	cx
	push	di
	push	es
	xor	ax, ax
	mov	cx, 256
	mov	es, f.buf(bx)
	xor	di, di
	rep stosw
	pop	es
	pop	di
	pop	cx
	pop	ax
	ret

/* - read_buffer(fp: bx, inode: di)		{ ax } */
read_buffer:
	call	alloc_buffer
	mov	f.buf(bx), ax
	call	get_zone
	beq	clear_buffer
	push	dx
	mov	dx, f.buf(bx)
	call	read_zone
	pop	dx
	ret

/* - write_buffer(fp: bx, inode: di)		{ ax } */
write_buffer:
	test	f.buf(bx), -1
	je	0f
	call	get_zone
	jne	1f
	call	alloc_zone
	call	set_zone
1:	push	dx
	mov	dx, f.buf(bx)
	call	write_zone
	pop	dx

/* - detach_buffer(fp: bx)			{ ax } */
detach_buffer:
	mov	ax, f.buf(bx)
	call	free_buffer
	mov	f.buf(bx), 0
0:	ret


/* - bytes_left_in_buffer(fp: bx) -> bytes_left_in_buffer: ax */
bytes_left_in_buffer:
	mov	ax, f.pos(bx)
	and	ax, 511
	neg	ax
	add	ax, 512
	ret


/* - get_fp(fd: bx) -> fp: bx, inode: di, tty: ZF */
get_fp:
	cmp	bx, N_OPEN
	bhis	error
	shl	bx, 1
	mov	di, bx
	mov	bx, p.fd(bp_di)
	test	bx, bx
	beq	error
	mov	di, f.inode(bx)
	cmp	bx, 1				/* ZF set if tty */
	ret


/* - sys.close */
sys.close:
	mov	si, bx
	call	get_fp
	je	1f
	test	bx, bx
	beq	error
	call	close_fp
1:	shl	si, 1
	mov	(si), 0
	ret

/* - sys.dup */
sys.dup:
	call	get_fp
	call	create_fd
	incb	f.links(bx)
	ret

/* - sys.dup2 */
sys.dup2:
	call	get_fp				/* source */
	push	bx
	mov	bx, si
	call	get_fp				/* dest */
	je	1f
	test	bx, bx
	je	1f
	call	close_fp
1:	shl	si, 1
	pop	bx
	mov	p.fd(bp_si), bx
				//mov ax, p.fd+2(bp); call t_printn
	incb	f.links(bx)
	ret

/* - sys.seek */
sys.seek:
	call	get_fp
	beq	error
_seek:
	shl	si, 1
	call	seek_table(si)
	mov	p.ax(bp), dx
	testb	f.mode(bx), 1
	je	1f
	call	write_buffer
	mov	f.pos(bx), dx
	ret
1:	cmp	dx, i.size(di)
	bhis	error
	mov	f.pos(bx), dx
	mov	ax, f.buf(bx)
	jmp	detach_buffer
seek_table: 0f; 1f; 2f
0:	mov	dx, cx
	ret
1:	mov	dx, f.pos(bx)
	add	dx, cx
	ret
2:	add	cx, i.size(di)
	mov	dx, cx
	ret

/* - sys.stat */
sys.stat:
	call	get_fp
	beq	error
	xchg	si, di
	mov	cx, [inode_size-[10*2]]/2
	push	es
	push	fs
	pop	es
	rep movsw
	pop	es
	ret


/* - sys.read */
sys.read:
	call	get_fp
	beq	tty.read
	testb	f.mode(bx), 1
	bne	error

/* - read_fp(fp: bx, inode: di, buf: fs:si, n: cx, proc: bp)
	-> n: p.ax { ax, cx } */
read_fp:
	mov	p.ax(bp), 0
	mov	ax, i.size(di)
	sub	ax, f.pos(bx)
	cmp	ax, cx
	jae	1f
	mov	cx, ax
	jcxz	0f
1:	test	f.buf(bx), -1
	jne	1f
	call	read_buffer
1:	call	bytes_left_in_buffer
	cmp	ax, cx
	ja	1f
	mov	cx, ax
	xor	ax, ax				/* ax=0 => we'll free buffer */
1:	mov	p.ax(bp), cx
	push	ds
	push	es
	push	si
	push	di
	push	fs
	pop	es
	mov	di, si
	lds	si, f.pos(bx)
	add	f.pos(cs:bx), cx
	and	si, 511
	rep movsb
	pop	di
	pop	si
	pop	es
	pop	ds
	test	ax, ax				/* buffer ended? */
	jne	0f
	mov	ax, f.buf(bx)
	jmp	detach_buffer
0:	ret


/* - sys.write */
sys.write:
	call	get_fp
	beq	tty.write
	testb	f.mode(bx), 1
	beq	error

/* - write_fp(fp: bx, inode: di, buf: fs:si, n: cx, proc: bp)
	-> n: p.ax { ax, cx } */
write_fp:
	mov	p.ax(bp), 0
	jcxz	0f
1:	test	f.buf(bx), -1
	jne	1f
	call	alloc_buffer
	mov	f.buf(bx), ax
	call	clear_buffer
1:	call	bytes_left_in_buffer
	cmp	ax, cx
	ja	1f
	mov	cx, ax
	xor	ax, ax				/* ax=0 => we'll free buffer */
1:	mov	p.ax(bp), cx
	push	ds
	push	es
	push	si
	push	di
	push	fs
	pop	ds
	les	di, f.pos(bx)
	add	f.pos(cs:bx), cx
	and	di, 511
	rep movsb
	pop	di
	pop	si
	pop	es
	pop	ds
	mov	cx, f.pos(bx)
	cmp	cx, i.size(di)
	jbe	1f
	mov	i.size(di), cx
1:	test	ax, ax				/* buffer ended? */
	beq	write_buffer
0:	ret


/*
 * namei
 */

	.bss
namei_buf:	.=.+16
/* - dir_entry(fp: bx, inode: di, name: fs:si)
	-> inode: di, end-of-name: si { ax } */
	.text
dir_entry:
1:	push	cx
	push	si
	push	fs
	push	ds
	pop	fs
	mov	cx, 16
	mov	si, namei_buf
	call	read_fp
	test	p.ax(bp), -1
	jne	9f
	xor	di, di				/* not found */
	pop	fs
	pop	si
	pop	cx
	ret
9:	pop	fs
	pop	si
	pop	cx
	push	si
	push	di
	push	cx
	mov	cx, 14
	mov	di, namei_buf+d.name
	mov	al, ')
2:	test	al, al
	je	3f
	seg	fs
	lodsb
	cmp	al, '/
	jne	3f
	mov	al, '\0
3:	scasb
	jne	4f
	loop	2b
	test	al, al
	bne	error				/* too long name */
	pop	cx
	add	sp, 4
	mov	di, (d.number+namei_buf)
	shl	di, inode_log
	add	di, d.inodes
	ret
4:	pop	cx
	pop	di
	pop	si
	j	1b

/* - empty_entry(fp: bx, inode: di) -> f.pos */
empty_entry:
	push	ax
	push	cx
	push	si
1:	mov	cx, 16
	mov	si, namei_buf
	push	fs
	push	cs
	pop	fs
	call	read_fp
	pop	fs
	test	p.ax(bp), -1
	je	9f
	test	(namei_buf+d.number), -1
	jne	1b
	sub	f.pos(bx), 16
9:	pop	si
	pop	cx
	pop	ax
	ret

/* - namei(fp: bx, name: fs:si, proc: bp)
	-> inode: di, basename: fs:si { ax, dx } */
namei:	push	cx
	mov	di, p.root(bp)
	seg	fs
	lodsb
	cmp	al, '/
	je	1f
	mov	di, p.pwd(bp)
	dec	si
1:	push	si
	xor	cx, cx
5:	seg	fs
	lodsb
	test	al, al
	je	4f
	cmp	al, '/
	jne	5b
	inc	cx				/* number of dirs */
4:	pop	si
	jcxz	9f
2:	testb	i.flags(di), I_D
	beq	error
	call	dir_entry
	beq	error
	call	release_fp
	loop	2b
9:	pop	cx
	ret


/* - do_link(fp: bx, inode: di, L-inode: ax, name: fs:si) { ax } */
do_link:
	push	cx
	push	si
	call	empty_entry
	mov	(namei_buf+d.number), ax
	push	di
	mov	di, namei_buf+d.name
	xor	ax, ax
	mov	cx, 7
	rep stosw
	mov	di, namei_buf+d.name
1:	seg	fs
	lodsb
	stosb
	test	al, al
	jne	1b
	pop	di
	push	fs
	push	cs
	pop	fs
	mov	si, namei_buf
	mov	cx, 16
	call	write_fp
	call	write_buffer
	pop	fs
	pop	si
	pop	cx
	ret


/* - copy_arg(source: fs:ax, dest: es:di) -> dest adjusted { ax } */
copy_arg:
	push	si
	mov	si, ax
1:	seg	fs
	lodsb
	stosb
	test	al, al
	jne	1b
	pop	si
	ret

/* - copy_args(args: fs:si) -> p.sp */
copy_args:
 	push	es
 	push	fs
 	pop	es
 	push	bx				/* *argv, argc */
 	push	di				/* **argv */
	mov	bx, 2
	xor	di, di
1:	seg	fs
 	lodsw
 	test	ax, ax
 	je	0f
	inc	di
	j	1b
0:	mov	(es:STACK_SIZE-4), di		/* save argc */
	mov	(es:STACK_SIZE-2), 2		/* save argv */
	inc	di
	shl	di, 1				/* di=first free chunk */
	sub	si, di
	xor	ax, ax
	stosw
2:	seg	fs
	lodsw
	test	ax, ax
	je	0f
	mov	(es:bx), di			/* save argv[i] */
	add	bx, 2
	call	copy_arg
	j	2b
0:	pop	di
 	pop	bx
 	pop	es
 	mov	p.sp(bp), STACK_SIZE-4
 	ret


/* - sys.open */
_open:
	call	create_fp
	mov	bx, di
	call	namei
	call	dir_entry
	beq	error
	jmp	release_fp
sys.open:
	call	_open
	call	create_fd
	mov	f.mode(bx), cl
	movb	f.links(bx), 1
	mov	f.inode(bx), di
	ret

/* - sys.creat */
sys.creat:
	call	create_fp
	mov	bx, di
	call	namei
	push	si
	push	di
	call	dir_entry
	pop	di
	pop	si
	bne	error
	call	release_fp
	call	alloc_inode
	push	ax
	call	do_link
	call	release_fp
	call	create_fd
	movb	f.mode(bx), 1
	movb	f.links(bx), 1
	pop	di
	shl	di, inode_log
	add	di, d.inodes
	mov	f.inode(bx), di
	mov	i.flags(di), cl
	movb	i.links(di), 1
	ret

/* - sys.exec */
	.text
sys.exec:
	call	_open
	testb	i.flags(di), I_X
	beq	error
	movb	f.mode(bx), 0
	mov	(break_end), fs
	mov	ax, i.size(di)
	add	ax, STACK_SIZE
	push	ax
	mov	si, cx
	call	_adjust_break
	pop	p.brk(bp)
	call	copy_args
	mov	si, STACK_SIZE
1:	mov	cx, 512
	call	read_fp
	mov	ax, p.ax(bp)
	// test	ax, ax
	// jns	2f
	// jmp	error		/* won't work ... */
2:	add	si, ax
	test	ax, ax
	jne	1b
	mov	sp, p.sp(bp)
	mov	ax, fs
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	pop	cx		/* argc */
	pop	si		/* argv */
	push	0x0200
	push	ax
	push	STACK_SIZE
	iret

/* - sys.chdir */
sys.chdir:
	call	_open
	testb	i.flags(di), I_D
	beq	error
	mov	p.pwd(bp), di
	ret


/*
 * system call
 */

/* - sys_table */
	.data
sys_table:
	0; sys.exit
	0; sys.fork
	4; sys.read
	4; sys.write
	4; sys.open
	0; sys.close
	4; sys.creat
	4; sys.seek
	0; sys.dup
	2; sys.dup2
	2; sys.brk
	0; sys.getpid
	0; sys.getppid
	0; sys.alloc
	0; sys.free
	4; sys.exec
	0; sys.sync
	2; sys.gtty
	2; sys.stty
	2; sys.chdir
	2; sys.stat

/* - system_call */
system_call:
	cld					/* DF + */
	cbw
	push	cx
	push	bx
	push	dx
	push	si
	push	di
	push	bp
	push	ds
	push	es
	push	fs
	mov	cx, cs
	mov	ds, cx				/* ds + */
	mov	es, cx				/* es + */
	mov	ss, cx				/* ss + */
	mov	bp, (current)			/* bp + */
	mov	p.sp(bp), sp
	mov	di, sp				/* di=old sp */
	xor	sp, sp				/* sp + */
	mov	fs, p.seg(bp)			/* fs + */
	cmp	ax, N_SYSCALLS
	jae	error
 	shl	ax, 2
 	mov	si, ax				/* si=sys_table entry */
 	mov	ax, sys_table+2(si)		/* ax=function */
 	mov	cx, sys_table(si)		/* cx=bytes to skip */
 	mov	si, 18(fs:di)			/* si=old pc */
 	add	18(fs:di), cx			/* pc + */
 	mov	cx, 2(fs:si)			/* cx + */
 	mov	si, (fs:si)			/* si + */
	mov	p.ax(bp), 0			/* return 0 by default */
 	call	ax
sys_return:
 	mov	ax, p.ax(bp)
	mov	sp, p.sp(bp)
 	mov	ss, p.seg(bp)
	pop	fs
	pop	es
	pop	ds
	pop	bp
	pop	di
	pop	si
	pop	dx
	pop	bx
	pop	cx
	iret

/* - error */
error:
	mov	p.ax(bp), -1
	j	sys_return
/* need to reset cs,ds,es,ss on stack */


/* - reset_segments() -> seg: (fs, ss:&fs, ss:&ds, ss:&es, ss:&cs) { bx } */
reset_segments:
	mov	fs, p.seg(bp)
	mov	bx, p.sp(bp)
	mov	(fs:bx), fs			/* fs */
	mov	2(fs:bx), fs			/* es */
	mov	4(fs:bx), fs			/* ds */
	mov	20(fs:bx), fs			/* cs */
	ret



/*
 * init
 */

/* - main */
init:
	cld					/* make df=0 */
	mov	cx, bss_len			/* clear bss */
	xor	ax, ax
	mov	di, bss_start
	rep stosw
	call	setup_disk
	mov	(9*4), keyboard_interrupt
	mov	(9*4+2), cs
	mov	(32*4), system_call
	mov	(32*4+2), cs
	call	create_process
	mov	bp, di
	mov	(current), bp
	mov	p.id(bp), ax
	mov	p.seg(bp), BEGIN_BREAK
	mov	ax, STACK_SIZE
	add	ax, init_task_size
	mov	p.brk(bp), ax
	call	adjust_break
	mov	p.root(bp), d.inodes+inode_size
	mov	p.pwd(bp), d.inodes+inode_size
	mov	p.fd(bp), 1			/* stdin */
	mov	p.fd+2(bp), 1			/* stdout */
	mov	p.fd+4(bp), 1			/* stderr */
	mov	si, init_task
	mov	di, STACK_SIZE
	mov	es, p.seg(bp)
	mov	cx, init_task_size
	rep movsb
	mov	ax, p.seg(bp)
	mov	ds, ax
	mov	es, ax
	mov	ss, ax
	mov	fs, ax
	mov	sp, STACK_SIZE
	ljmp	BEGIN_BREAK, STACK_SIZE

/* - init task */
	.text
init_task:
	sys	exec; filename; args
	0xfeeb
filename = .-init_task+STACK_SIZE; </bin/sh\0>
args = .-init_task+STACK_SIZE; 0;
init_task_size = .-init_task


	.bss
bss_len = [.-bss_start+1]/2



/* - simple console driver
 *
 * configure cursor/attr by changing t_x/t_y/t_a
 *
 * t_putchar(char: al)				{ ax }
 * t_prints(string: cs:si)			{ si, ax }
 * t_printn(number: ax)
 */
.if tests
	.text
t_y: 0; t_x: 0; t_a: 7
t_cols: 80
t_putchar:
	push	bx
	push	ds
	mov	ah, (cs:t_a)
	push	ax
	mov	ax, (cs:t_y)
	mulb	(cs:t_cols)
	add	ax, (cs:t_x)
	shl	ax, 1
	mov	bx, ax
	push	0xb800
	pop	ds
	pop	(bx)
	pop	ds
	pop	bx
	incb	(cs:t_x)
	ret
t_prints:
	cld
1:	seg	cs
	lodsb
	test	al, al
	je	1f
	call	t_putchar
	j	1b
1:	ret
t_printn:
	pusha
	call	3f
	popa
	ret
3:	mov	cx, 4
2:	push	ax
	shr	ax, 4
	dec	cx
	je	1f
	call	2b
1:	pop	ax
	and	al, 15
	mov	bx, 1f
	seg	cs
	xlat
	call	t_putchar
	ret
1:	<0123456789abcdef>
.endif

