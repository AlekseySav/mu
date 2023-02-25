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
memory_map: 	.=.+N_BUFFERS/8
fsp:		.=.+[N_FSP*fp_size]
proc:		.=.+[N_PROC*proc_size]
current:	.=.+2

	.text
	jmp	init

error:
	mov	p.ax(bp), -1
	jmp	sys_return


/*
 * memory driver
 */

/* - alloc(map: ds:si, count: cx) -> n: ax 	{ cx, si } */
	.text
alloc:	push	dx
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

/* - free(map: ds:si, count: cx, n: ax) 	{ cx } */
	.text
free:	cmp	ax, cx
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
	call	alloc
	shl	ax, 9-4
	add	ax, BEGIN_BUFFERS
	pop	cx
	pop	si
	ret

/* - free_buffer(ptr: ax)			{ ax } */
	.text
free_buffer:
	push	cx
	push	si
	sub	ax, BEGIN_BUFFERS
	shr	ax, 9-4
	mov	cx, N_BUFFERS
	mov	si, memory_map
	call	free
	pop	si
	pop	cx
	ret


/* - adjust_break(size: ax)			{ ax } */
	.text
adjust_break:
	push	di
	push	cx
	add	ax, 15
	mov	cx, ax
	shr	cx, 1				/* bytes -> words */
	shr	ax, 4				/* bytes -> segments */
	add	ax, (break_end)
	cmp	ax, END_BREAK
	bho	error
	push	es
	mov	es, (break_end)
	mov	(break_end), ax
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
	call	alloc
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
	call	free
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
	call	alloc
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
	call	free
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
kb.state: .=.+2					/* 1=shift, 2=ctrl */
kb.queue: .=.+TTY_SIZE
kb.head: .=.+2
kb.tail: .=.+2


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


/* - tty.read(buf: fs:si, cx: n) -> n: p.ax */
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
	call	free_buffer
	jmp	sys_return0

/* - sys.exit */
sys.exit:
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
	mov	cx, p.brk(bp)
	shr	cx, 1
	rep movsw
	pop	es
	pop	ds
	jmp	sys_return0


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

/* - getfp(fd: bx) -> fp: bx, inode: di, tty: ZF */
getfp:
	shl	bx, 1
	mov	di, bx
	mov	bx, p.fd(bp_di)
	test	bx, bx
	beq	error
	mov	di, f.inode(bx)
	cmp	bx, 1				/* ZF set if tty */
	ret


/* - sys.write */
9:	jmp	sys_return0
sys.write:
	jcxz	9b
	call	getfp
	beq	tty.write
	j .

/* need to reset cs,ds,es,ss on stack */
sys_return0:
	mov	p.ax(bp), 0
sys_return:
	j .

/* - init */
init:
	cld					/* make df=0 */
	call	setup_disk
	mov	(9*4), keyboard_interrupt
	mov	(9*4+2), cs
.if tests
	call	run_tests
.endif

	call	create_process
	mov	bp, di
	mov	(current), bp
	mov	p.id(bp), ax
	mov	p.root(bp), d.inodes+inode_size
	mov	p.pwd(bp), d.inodes+inode_size
	mov	p.seg(bp), BEGIN_BREAK
	mov	p.brk(bp), 512
	mov	p.fd(bp), 1			/* stdin */
	mov	p.fd+2(bp), 1			/* stdout */
	mov	p.fd+4(bp), 1			/* stderr */


	mov	bx, 1
	mov	cx, 10
	mov	si, lalala
	push	ds
	pop	fs
	call	sys.write


	mov	ax, STACK_SIZE
	add	ax, init_task_size
	call	adjust_break
	mov	si, init_task
	mov	di, STACK_SIZE
	mov	es, p.seg(bp)
	mov	cx, init_task_size
	rep movsb
	ljmp	BEGIN_BREAK, 0

lalala: <hello!1234>

.if tests
	.text
/* - simple console driver
 *
 * configure cursor/attr by changing t_x/t_y/t_a
 *
 * t_putchar(char: al)				{ ax }
 * t_prints(string: cs:si)			{ si, ax }
 * t_printn(number: ax)
 */
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

/* - assert
 *
 * a_begin(name)				{ ax, si }
 * a_end()					{ ax, si }
 * assert_eq(condition: EF)
 */
a_dots: <... \0>
a_ok: <ok\0>
a_id: 0
a_begin:
	mov	(cs:a_id), 0
	pop	si
	call	t_prints
	push	si
	mov	si, a_dots
	jmp	t_prints
a_end:
	mov	si, a_ok
	call	t_prints
	incb	(cs:t_y)
	movb	(cs:t_x), 0
	ret
assert_eq:
	je	1f
	movb	(cs:t_x), 0
	incb	(cs:t_y)
	mov	(cs:t_a), 4
	mov	si, 2f
	call	t_prints
	mov	ax, (cs:a_id)
	call	t_printn
	mov	si, 4f
	call	t_prints
	j .
1:	inc	(cs:a_id)
	ret
2:	<Assertion #\0>
4:	< failed\0>

	.text

/* - helper functions */
clear_proc:
	mov	di, proc
	mov	cx, N_PROC*proc_size
	xor	al, al
	rep stosb
	ret

run_tests:
/* - test allocator */
	call	a_begin; <alloc\0>
	mov	cx, N_BUFFERS
	mov	dx, BEGIN_BUFFERS
1:	call	alloc_buffer; cmp ax, dx; call assert_eq
	add	dx, 512/16
	loop	1b
0:
	mov	cx, N_BUFFERS
	mov	dx, END_BUFFERS-[512/16]
1:	mov	ax, dx
	call	free_buffer
	call	alloc_buffer; cmp ax, dx; call assert_eq
	call	free_buffer
	sub	dx, 512/16
	loop	1b
0:
	call	a_end

/* - test break */
	call	a_begin; <break\0>
	mov	ax, 10
	call	adjust_break; cmp (break_end), BEGIN_BREAK+1; call assert_eq
	mov	ax, 16*100
	call	adjust_break; cmp (break_end), BEGIN_BREAK+101; call assert_eq
	mov	cx, END_BREAK-BEGIN_BREAK-101
	mov	si, (break_end)
1:	mov	ax, 1
	inc	si
	call	adjust_break; cmp (break_end), si; call assert_eq
	loop	1b
	call	a_end
	mov	(break_end), BEGIN_BREAK

/* - test proc */
	call	a_begin; <proc\0>
	mov	cx, 1
	mov	si, proc
1:	call	create_process
	cmp	di, si; call assert_eq
	cmp	ax, cx; call assert_eq
	mov	p.id(di), ax
	cmp	ax, p.id(di); call assert_eq
	mov	bp, di
	call	sys.getpid; cmp ax, p.ax(bp); call assert_eq
	add	si, proc_size
	inc	cx
	cmp	cx, N_PROC
	jl	1b
0:
	mov	si, 2*proc_size+proc
	mov	p.id(si), 0
	call	create_process
	cmp	di, si; call assert_eq
	cmp	ax, 3; call assert_eq
0:
	call	clear_proc
	call	a_end

	ret
.endif

/* - init task */
	.text
init_task:
	mov	ax, 0x0e00|':
	int	0x10
	j .
init_task_size: .-init_task

