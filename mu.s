/*
 * munix
 * 	by default, DF=0, DS=CS, SI=arg1, CX=arg2, BX=fd, BP=process
 *
 * memory layout:
 *	00000		initptr 	kernel		~20K
 *	initptr		initptr+512	init task	512 bytes
 *	initptr+512	0x50000		process memory	~300K
 *	0x50000		0x80000		buffers		192K (384 buffers)		
 * bugs:
 *	if create fails, last '/' of path might be replaced with 0
 */
	.orig 	mm.image

	.text; text_start:
	.data; data_start:
	.bss; bss_start:

	.even
fsp:	.=.+[N_OPEN*fp_size]
proc:	.=.+[N_PROC*proc_size]
	.data
current: proc

	.text
	jmp	init

/*
 * out_b, out_w
 *
 * in: AX(AL)=value, CX(CL)=command, DX=data port, BX=command port
 * out_w corrupts AX, CX
 */
out_b:	cli
	xchg	dx, bx
	xchg	ax, cx
	outb
	xchg	ax, cx
	xchg	dx, bx
	outb
	sti
	ret
out_w:	call	out_b
	shr	ax, 8
	shr	cx, 8
	j 	out_b

/*
 * buffer allocator
 *
 * in: DF=0, DS=CS
 * out: AX:0=free 512-byte block
 */
allocb:	push	cx
	push	si
	mov	cx, N_BUFFERS/16
	mov	si, memmap
	call	_alloc
	pop	si
	pop	cx
	shl	ax, 5
	add	ax, LOW_MEMORY
	ret

freeb:	test	ax, ax
	je	0f
	push	di
	mov	di, memmap
	sub	ax, LOW_MEMORY
	shr	ax, 5
	call	_free
	pop	di
0:	ret

/*
 * zone allocator
 *
 * in: DF=0, DS=CS
 * out: AX=free 512-byte disk zone
 */
allocz:	push	cx
	push	si
	mov	cx, N_ZONES/16
	mov	si, mm.blkmap
	call	_alloc
	pop	si
	pop	cx
	ret

freez:	push	di
	mov	di, memmap
	sub	ax, LOW_MEMORY
	shr	ax, 5
	call	_free
	pop	di
	ret

/*
 * generic alloc
 *
 * in: DF=0, DS=CS, SI=bitmap, CX=size in words
 */
_alloc:	push	dx
	mov	dx, cx
1:	lodsw
	cmp	ax, -1
	jne	2f
	loop	1b
	jmp	sys.error
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

/*
 * generic free
 *
 * in: DS=CS, DI=bitmap
 */
_free:	push	bx
	push	cx
	mov	bx, ax
	shr	bx, 4
	mov	cx, ax
	and	cx, 15
	mov	ax, 1
	shl	ax, cl
	not	ax
	and	(bx_di), ax
	pop	cx
	pop	bx
	ret

	.bss
memmap:	.=.+[N_BUFFERS/8]

/*
 * keyboard driver
 */
	.text

do_keyboard:
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
	mov	si, (kb.tail)
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

2:	mov	cl, al				/* shift */
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

	.data
kb.table: 1f; 2f

1:	<\0\e1234567890-=\b\t>
	<qwertyuiop[]\n\0>			/* ctrl unused */
	<asdfghjkl;'`>; .byte 0x81
	<\\zxcvbnm,./>; .byte 0x81
	<*\0 \0>				/* alt capslock unused */
kb.count = .-1b

2:	<\0\e!@#$%^&*()_+\b\t>
	<QWERTYUIOP[]\n\0>
	<ASDFGHJKL:"~>; .byte 0x81
	<\\ZXCVBNM<\>?>; .byte 0x81
	<*\0 \0>

kb.action:
	.byte kb.no, kb.ch			/* line 1 */
	.byte kb.ch, kb.ch, kb.ch, kb.ch, kb.ch
	.byte kb.ch, kb.ch, kb.ch, kb.ch, kb.ch
	.byte kb.ch, kb.ch, kb.bs, kb.ch
	.byte kb.ch, kb.ch, kb.ch, kb.ch, kb.ch	/* line 2 */
	.byte kb.ch, kb.ch, kb.ch, kb.ch, kb.ch
	.byte kb.ch, kb.ch, kb.ch, kb.no
	.byte kb.ch, kb.ch, kb.ch, kb.ch, kb.ch	/* line 3 */
	.byte kb.ch, kb.ch, kb.ch, kb.ch, kb.ch
	.byte kb.ch, kb.ch, kb.md
	.byte kb.ch, kb.ch, kb.ch, kb.ch, kb.ch	/* line 4 */
	.byte kb.ch, kb.ch, kb.ch, kb.ch, kb.ch
	.byte kb.ch, kb.md
	.byte kb.ch, kb.no, kb.ch, kb.no	/* line 5 */

	.bss
kb.state: .=.+2					/* 1=shift, 2=ctrl, 3=shift+ctrl */
kb.queue: .=.+TTY_SIZE
kb.head: .=.+2
kb.tail: .=.+2


/*
 * disk driver
 * temporary: using bios
 */
	.text

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

read_sector:
	mov	(disk_mode), 0x0201
	j	0f
write_sector:
	mov	(disk_mode), 0x0301
0:	pusha
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
	popa
	ret

read_buffer:
	push	es
	push	bx
	les	bx, f.pos(bx)
	shr	bx, 9
	shl	bx, 1
	mov	ax, i.zones(bx_di)
	xor	bx, bx
	and	bx, 511
	call	read_sector
	pop	bx
	pop	es
	ret

write_buffer:
	push	es
	push	bx
	les	bx, f.pos(bx)
	shr	bx, 9
	shl	bx, 1
	mov	ax, i.zones(bx_di)
	test	ax, ax
	jne	1f
	call	allocz
	mov	i.zones(bx_di), ax
1:	xor	bx, bx
	and	bx, 511
	call	write_sector
	pop	bx
	pop	es
	ret

	.bss
disk_mode: .=.+2
dev: .=.+2
heads: .=.+2
sectors: .=.+2

/*
 * tty i/o
 *
 * in: DF=0, DS=CS, FS:SI=buf, CX=count
 * out: p.ax(bp)=count
 */
	.text

tty.read:
	mov	p.ax(bp), cx
	push	fs
	pop	es
	mov	di, si
1:	nop
	mov	si, (kb.head)
	cmp	si, (kb.tail)
	je	1b
	inc	(kb.head)
	and	(kb.head), TTY_SIZE-1
	add	si, kb.queue
	lodsb
	stosb
	cmp	al, '\n
	je	2f
	loop	1b
	inc	cx
2:	dec	cx
	sub	p.ax(bp), cx
	ret

tty.write:
	mov	p.ax(bp), cx
tty._write:
	push	es
	les	di, (cursor)
1:	seg	fs
	lodsb
	cmp	al, '\s
	jb	2f
	mov	ah, 7
	stosw
3:	loop	1b
	mov	ax, di
	mov	(cursor), ax
	shr	ax, 1
	pop	es
	mov	cx, 0x0e0f			/* update cursor */
	mov	bx, 0x3d4
	mov	dx, 0x3d5
	jmp	out_w
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
cursor:	0; 0xb800


/*
 * system calls
 */

sys.alloc:
	call	allocb
	mov	p.ax(bp), ax
	ret

sys.free:
	mov	ax, bx
	jmp	freeb


/*
 * filesystem
 */

/*
 * in: bx=fd
 * out: bx=fp, di=inode
 */
getfp:	shl	bx, 1
	mov	di, bx
	mov	bx, p.fd(bp_di)
	test	bx, bx
	beq	sys.error
	mov	di, f.inode(bx)
	cmp	bx, 1				/* ZF set if tty */
	ret

/* di=fd */
newfd:	push	cx
	mov	cx, N_OPEN
	lea	di, p.fd(bp)
	xor	ax, ax
	repne scasw
	bne	sys.error
	sub	di, 2
	pop	cx
	ret

/* bx=fp */
newfp:	push	cx
	mov	cx, N_OPEN
	mov	bx, fsp
1:	testb	f.links(bx), -1
	je	2f
	add	bx, fp_size
	loop	1b
	jmp	sys.error
2:	mov	f.buf(bx), 0
	mov	f.pos(bx), 0
	pop	cx
	ret


/*
 * namei
 *
 * in: FD=0, FS:SI=name, BP=process, BX=fp
 * out: DI=inode
 * corrupts: SI
 */
	.bss
namei_cnt: .=.+2
namei_buf: .=.+dir_size

	.text

/* compare namei_buf+dir.name and fs:si */
name_cmp:
	push	di
	mov	di, namei_buf+dir.name
	mov	cx, 14
1:	seg	fs
	lodsb
	test	al, al
	je	2f
	cmp	al, '/
	je	2f
	scasb
	jne	0f
	loop	1b
	jmp	sys.error			/* name is too long */
2:	dec	si
	testb	(di), -1			/* ok if al is 0 */
0:	pop	di
	ret

namei:
	push	cx
	movb	f.mode(bx), 0
	mov	di, p.pwd(bp)
	cmpb	(fs:si), '/
	jne	1f
	inc	si
	mov	di, p.root(bp)
1:	testb	(fs:si), -1			/* namei("/") */
	je	0f
	push	si
	xor	cx, cx
	xor	si, si
	call	_seek				/* scan from start */
	pop	si
	test	i.flags(di), 0x40
	beq	sys.error			/* not dir */
	push	i.size(di)
	pop	(namei_cnt)
	shr	(namei_cnt), dir_log
	beq	sys.error
2:	push	si
	mov	si, namei_buf
	mov	cx, dir_size
	push	di
	call	_read				/* next entry */
	pop	di
	pop	si
	push	si
	call	name_cmp
	je	3f
	pop	si
	dec	(namei_cnt)
	jne	2b
	jmp	sys.error
3:	add	sp, 2
	testb	(fs:si), -1			/* path ended */
	je	5f
	inc	si				/* skip '/' */
5:	mov	di, (namei_buf+dir.n)
	shl	di, inode_log
	add	di, mm.inodes			/* di=new inode */
	j	1b
0:	pop	cx
	ret

/*
 * open
 *
 * in: FS:SI=name, CX=mode
 */
 	.text

sys.open:
	test	cx, 0xfffe
	bne	sys.error
	push	cx
	call	newfd
	push	di
	call	newfp
	call	namei
	mov	f.inode(bx), di
	pop	di
	pop	f.mode(bx)
	movb	f.links(bx), 1
	mov	f.buf(bx), 0
	mov	f.pos(bx), 0
	mov	(di), bx
	sub	di, bp
	sub	di, p.fd
	shr	di, 1
	mov	p.ax(bp), di
	ret


/*
 * create
 *
 * in: FS:SI=name, CX=flags (-d---rwx)
 */
sys.create:
// 	testb	CX, 0xffb8
// 	bne	sys.error
// 	mov	di, si
// 	mov	bx, si
// 	mov	al, '/
// 1:	testb	(fs:di), -1
// 	je	2f
// 	scasb					/* find last '/' */
// 	jne	1b
// 	lea	bx, -1(di)
// 	j	1b
// 2:	cmp	bx, di
// 	jne	3f
// 	mov	di, p.pwd(bp)			/* create("file") */
// 	cmpb	(bx), '/
// 	jne	4f
// 	mov	p.root(bp)			/* create("/file") */
// 	j	4f
// 3:	movb	(bx), '\0
// 	push	bx
// 	call	newfp
// 	call	namei				/* find parent dir */
// 	pop	bx
// 	movb	(bx), '/
// 4:	call	newfp
// 	mov	(bx), di
// 	mov	f.buf(bx), 0
// 	mov	f.pos(bx), 0
// 	movb	f.mode(bx), 1
// 	push	si
// 	mov	si, 2
// 	xor	cx, cx
// 	call	_seek				/* seek end */
// 	pop	si
// 	call	_write


/*
 * close
 *
 * in: BX=fd
 */
	.text

sys.close:
	mov	si, bx
	call	getfp
	jz	0f
	decb	f.links(bx)
	jnz	0f
	testb	f.mode(bx), 1
	je	1f
	push	bx
	mov	ax, fs.blkmap/512
	mov	bx, mm.blkmap
	call	write_sector			/* flush blkmap */
	pop	bx
	test	f.buf(bx), -1
	je	0f
	call	write_buffer			/* flush buffer */
1:	mov	ax, f.buf(bx)
	call	freeb
0:	mov	(si), 0				/* free fd */
	ret


/*
 * dup, dup2
 */
	.text

sys.dup:
	call	newfd
	mov	si, di
	j	1f
sys.dup2:
	push	si
	push	bx
	mov	bx, si
	call	sys.close
	pop	bx
	pop	si
1:	call	getfp
	jz	2f
	inc	f.links(di)
2:	mov	(si), di
	mov	p.ax(bp), 0
	ret


/*
 * seek
 *
 * in: DS=CS, SI=new pos, CX=mode, BX=fd
 * out: p.ax(bp)=new offset
 */
	.text

sys.seek:
	call	getfp
	beq	sys.error			/* trying to seek tty */
_seek:
	xchg	si, cx
	shl	si, 1
	call	4f(si)
	cmp	ax, i.size(di)
	jbe	0f
	testb	f.mode(bx), 1
	beq	sys.error			/* out of file in r mode */
0:	mov	p.ax(bp), ax
	mov	f.pos(bx), ax
	mov	ax, f.buf(bx)
	call	freeb
	mov	f.buf(bx), 0			/* release old buffer */
	ret

1:	mov	ax, cx				/* SEEK_SET */
	ret
2:	mov	ax, f.pos(bx)			/* SEEK_CUR */
	add	ax, cx
	ret
3:	mov	ax, i.size(di)			/* SEEK_END */
	add	ax, cx
	ret

	.data
4:	1b; 2b; 3b

/*
 * read/write
 *
 * in: DF=0, DS=CS, FS:SI=buf, CX=count, BX=fd
 * out: p.ax(bp)=count
 */

9:	jmp	sys.zero

sys.read:
	jcxz	9b
	call	getfp
	beq	tty.read
	testb	f.mode(bx), 1
	bne	sys.error
_read:	mov	dx, f.pos(bx)
	cmp	dx, i.size(di)
	beq	sys.zero			/* eof? */
	call	r_count				/* eval actual count */
1:	test	f.buf(bx), -1			/* buffer not allocated? */
	jnz	1f
	call	allocb
	mov	f.buf(bx), ax
	call	read_buffer
1:	mov	p.ax(bp), cx
	push	ds
	push	es
	mov	di, si
	lds	si, f.pos(bx)
	add	f.pos(cs:bx), cx		/* adjust cursor */
	and	si, 511
	push	fs
	pop	es
	rep movsb
	pop	es
	pop	ds
	test	f.pos(bx), 511			/* buffer ended? */
	jnz	0f
	mov	ax, f.buf(bx)
	call	freeb
	mov	f.buf(bx), 0			/* release */
0:	ret

sys.write:
	jcxz	9b
	call	getfp
	beq	tty.write
	testb	f.mode(bx), 1
	beq	sys.error
_write:	call	w_count				/* eval actual count */
1:	test	f.buf(bx), -1			/* buffer not allocated? */
	jnz	1f
	call	allocb
	mov	f.buf(bx), ax
1:	mov	p.ax(bp), cx
	push	di
	push	ds
	push	es
	les	di, f.pos(bx)
	add	f.pos(bx), cx			/* adjust cursor */
	and	di, 511
	push	fs
	pop	ds
	rep movsb
	pop	es
	pop	ds
	pop	di
	test	f.pos(bx), 511			/* buffer ended? */
	jnz	0f
	call	write_buffer			/* flush */
	mov	ax, f.buf(bx)
	call	freeb
	mov	f.buf(bx), 0			/* release */
0:	ret

/*
 * r_count: cx=min(cx,i.size,sector)
 * w_count: cx=min(cx,sector)
 * dx=sector
 */
r_count:
	add	cx, f.pos(bx)
	cmp	cx, i.size(di)
	jbe	1f
	mov	cx, i.size(di)
1:	sub	cx, f.pos(bx)
w_count:
	mov	dx, f.pos(bx)
	and	dx, 511
	neg	dx
	add	dx, 512				/* dx=rest bytes in sector */
	cmp	cx, dx
	jbe	1f
	mov	cx, dx
1:	ret

/*
 * process manager
 */
	.text

sys.brk:
	add	si, (proc.end)
	mov	p.ax(bp), si
	cmp	si, LOW_MEMORY
	bhis	sys.error
	mov	(proc.end), si
	ret


sys.exit:
	mov	p.id(bp), 0
	mov	ax, p.brk(bp)
	sub	(initend_seg), ax		/* dealloc memory */
	mov	bp, p.parent(bp)
	mov	(current), bp
	mov	fs, p.seg(bp)
	jmp	sys.return


/*
 * fork
 */
	.text
sys.fork:
	mov	p.ax(bp), 1			/* 1 to parent */
	mov	si, proc
	mov	cx, N_PROC
1:	test	(si), -1
	je	2f
	add	si, proc_size
	loop	1b
	jmp	sys.error
2:	mov	ax, (proc.end)
	mov	p.seg(si), ax
	add	ax, p.brk(bp)
	cmp	ax, LOW_MEMORY
	bhis	sys.error			/* out of memory */
	mov	(proc.end), ax
	mov	p.id(si), 1			/* later will be unique id */
	mov	p.parent(si), bp
	mov	(current), si
	push	si
	lea	di, p.sp(si)
	lea	si, p.sp(bp)
	mov	cx, [proc_size-p.sp]/2
	rep movsw				/* copy process meta */
	pop	si
	push	es
	mov	es, p.seg(si)
	push	es
	mov	cx, p.brk(bp)
	mov	bp, si				/* new bp */
	xor	si, si
	xor	di, di
	shl	cx, 3
	rep seg fs movsw			/* copy process content */
	pop	fs				/* new fs */
	pop	es
	jmp	fork_return


/*
 * exec
 *
 * in: FS:SI=name
 */
	.text
sys.exec:
	xor	cx, cx
	call	sys.open
	xor	si, si
1:	push	si
	mov	cx, 512
	call	_read
	pop	si
	test	p.ax(bp), -1
	jz	2f				/* eof */
	add	si, p.ax(bp)
	j	1b
2:	mov	(exec.addr), fs
	mov	ax, fs
	mov	ds, ax
	mov	es, ax
	xor	sp, sp
	ljmp	(cs:exec.addr)

	.data
proc.end: initend_seg

	.bss
exec.addr: .=.+4

/*
 * system calls
 */
	.data
sys.table:
	sys.exit; 0
	sys.fork; 0
	sys.read; 4
	sys.write; 4
	sys.open; 4
	sys.close; 0
	sys.create; 4
	sys.seek; 4
	sys.dup; 0
	sys.dup2; 2
	sys.brk; 2
	sys.exec; 2
	sys.alloc; 0
	sys.free; 0

N_SYSCALLS = [.-sys.table]/4

	.text
syscall:
	cld
	push	cx
	push	dx
	push	bx
	push	si
	push	di
	push	bp
	mov	cx, cs
	mov	ds, cx
	mov	es, cx
	mov	bp, (current)
	mov	p.sp(ds:bp), sp
	mov	fs, p.seg(ds:bp)
	cbw
	cmp	ax, N_SYSCALLS
	jae	sys.error
	shl	ax, 2
	mov	si, ax
	mov	ax, sys.table(si)		/* ax=function */
	mov	dx, sys.table+2(si)
	mov	si, sp
	mov	di, 6*2(ss:si)			/* di=old pc */
	add	6*2(ss:si), dx
	mov	ss, cx				/* cx is cs */
	mov	cx, sp
	mov	sp, mm.stack-20
	mov	si, (fs:di)
	mov	cx, 2(fs:di)
	call	ax
1:	mov	sp, p.sp(bp)
	mov	cx, p.seg(bp)
	mov	ax, p.ax(bp)
	mov	ss, cx
2:	mov	ds, cx
	mov	es, cx
	mov	fs, cx
	pop	bp
	pop	di
	pop	si
	pop	bx
	pop	dx
	pop	cx
	iret

sys.error:
	mov	p.ax(bp), -1
	j	1b
sys.zero:
	mov	p.ax(bp), 0
sys.return:
	j	1b
fork_return:
	mov	sp, p.sp(bp)
	mov	cx, p.seg(bp)
	mov	ss, cx
	mov	si, sp
	mov	7*2(ss:si), cx			/* new CS */
	xor	ax, ax				/* 0 to child */
	j	2b

/*
 * init
 */
	.bss
running: .=.+2

	.text

init:
	cld
	xor	al, al
	mov	di, bss_start
	mov	cx, bss_len
	rep stosb
.if debug
	mov	(3*4), do_debug
	mov	(3*4+2), cs
.endif
	mov	(9*4), do_keyboard
	mov	(9*4+2), cs
	mov	(32*4), syscall
	mov	(32*4+2), cs

	call	setup_disk

	mov	bp, proc
	mov	(current), bp
	movb	p.id(bp), 1
	mov	p.root(bp), mm.inodes+inode_size
	mov	p.pwd(bp), mm.inodes+inode_size
	mov	p.seg(bp), cs
	mov	p.brk(bp), 512
	mov	p.fd(bp), 1			/* stdin */
	mov	p.fd+2(bp), 1			/* stdout */
	mov	p.fd+4(bp), 1			/* stderr */

	sys	open; filepath; 0
	mov	bx, ax
	sys	read; initptr; 512
	sys	close

	mov	p.seg(bp), initseg
	mov	sp, 512
	//j .

	incb	(running)			/* initialization ended */

	ljmp	initseg, 0

	.data
filepath: </etc/init\0>

	.text; text_len = .-text_start
	.data; data_len = .-data_start
	.bss; bss_len = .-bss_start

initseg = [text_len+data_len+bss_len+15+mm.image]/16
initptr = initseg*16
initend_seg = [initptr+512]/16
