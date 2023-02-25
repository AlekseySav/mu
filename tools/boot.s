/*
 * boot errors:
 *	#0 -- disk setup error
 *	#1 -- entered bad inode number
 *	#2 -- disk read error (fs metainfo)
 *	#3 -- bad inode
 *	#4 -- reading image failed (probably bad inode)
 */

bootseg = 0x5000
max_size = 47*512

boot_tries = 100
boot_debug = 0
boot_delay = 0
disk_setup = 1

	.text
	jmp 	boot
	.fill 	125

dev: 128
sectors: 63
heads: 16
tries: 0
ten: 10
inode = d.image
meta_zones = d.meta_zones


/* - print(msg, ds=cs)				{ si ax } */
print:	pop	si
1:	lodsb
	test	al, al
	je	2f
	mov	ah, 0x0e
	int	0x10
	j	1b
2:	jmp	si

/* - printn(number: ax) */
.if boot_debug
printn:
	pusha
	call	2f
	mov	ax, 0x0e20
	int	0x10
	popa
	ret
2:	xor	dx, dx
	div	(cs:ten)
	push	dx
	test	ax, ax
	je	1f
	call	2b
1:	pop	ax
	add	al, '0
	mov	ah, 0x0e
	int	0x10
	ret
.endif

/* - error(...) */
error:
	call	print; <\n\rboot failed (#>; errno: <0)\n\r\0>
	int	0x19

/* - read_sector(number: ax, buffer: es:bx) */
read_sector:
	pusha
	xor	dx, dx
	div	(sectors)			/* ax = cyl x head, dx = sector - 1 */
	mov	cl, dl
	inc	cl				/* cl = sector */
	divb	(heads)				/* al = cylinder, ah = head */
	mov	dh, ah
	mov	ch, al
	mov	dl, (dev)
	mov	ax, 0x0201
	int	0x13
	jc	error
	popa
	ret


/* - indent_level(inode: es:di, buffer: es:si)	{ ax } */
indent_level:
	push	bx
	mov	ax, *i.zones+[2*9](es:di)
	mov	bx, si
	call	read_sector
	pop	bx
	ret


boot:	mov	ax, 0x07c0
	mov	ds, ax
	mov	ax, bootseg
	mov	es, ax
	xor	si, si
	xor	di, di
	mov	cx, 512/2
	cld rep movsw				/* move to bootseg */
	jmp	bootseg, 1f
1:	xor	ax, ax
	mov	es, ax				/* es=ss=fs=0, ds=cs */
	mov	fs, ax
	cli
	mov	ss, ax
	xor	sp, sp
	sti
	push	cs
	pop	ds
	mov	(dev), dl
	call	print; <Loading mu.s...\n\r\0>

/* - disk setup (errno=0) */
.if disk_setup
	movb	(tries), boot_tries
1:	mov	ah, 8
	int	0x13
	jnc	1f
	dec	(tries)
	beq	error
	j 	1b
1:	inc	dh
	mov	(heads), dh
	and	cl, 0x3f
	mov	(sectors), cl
.endif
	incb	(errno)

/* - pick inode (errno=1) */
.if boot_delay
	mov	dx, boot_delay
1:	mov	cx, -1
2:	loop	2b
	dec	dx
	jne	1b				/* make delay */
	mov	ah, 2
	int	0x16
	test	al, 8				/* alt pressed ? */
	je	2f
	call	print; <image inode: \0>
	xor	bx, bx
1:	xor	ah, ah
	int	0x16
	mov	ah, 0x0e
	int	0x10
	cmp	al, '\r
	je	1f
	sub	al, '0
	cmp	al, 10
	bhis	error
	xor	ah, ah
	xchg	ax, bx				/* bx=digit, ax=number */
	mulb	(ten)
	add	bx, ax
	j	1b
1:	mov	(inode), bx			/* save inode */
2:
.endif
	incb	(errno)

/* - get fs metainfo (errno=2) */
	mov	bx, UNMAPPED_ZONES*512
	mov	ax, UNMAPPED_ZONES
	mov	cx, (meta_zones)
	sub	cx, ax
1:	call	read_sector
	inc	ax
	add	bx, 512
	loop	1b
	incb	(errno)

/* - check image inode (errno=3) */
	mov	di, (inode)
	shl	di, inode_log
	add	di, d.inodes
	testb	*i.flags(es:di), I_IMAGE
	beq	error
	cmp	*i.size(es:di), max_size
	bhis	error
	incb	(errno)

/* - read image (errno=4)*/
	lea	si, *i.zones(di)
	xor	cx, cx
	mov	dx, *i.size(es:di)
	mov	bx, KERNEL_OFFSET
1:	seg es
	lodsw
	call	read_sector
	add	bx, 512
	add	cx, 512
	cmp	cx, dx
	jae	3f
	cmp	cx, 512*9
	jne	2f
	mov	si, 0xfc00			/* get some unused sector */
	call	indent_level
2:	j	1b
3:


	mov	ax, 2
	int	0x10				/* clear screen */
	mov	dl, (dev)
	push	es
	pop	ds
	jmp	0, KERNEL_OFFSET
