/*
 * boot errors:
 *	#0 -- entered bad inode number
 *	#1 -- getting disk info failed
 *	#2 -- reading fs header failed
 *	#3 -- used special inode
 *	#4 -- reading image failed (probably bad inode)
 */

usb_loader = 1
boot_tries = 100
boot_delay = 0
boot_debug = 0

	.text

.if usb_loader
	jmp 	boot
	.fill 	125
.endif

boot:	jmp	0x07c0, 1f			/* setup cs */
1:	mov	ax, cs				/* setup ds & stack */
	mov	ds, ax
	cli
	mov	ss, ax
	mov	sp, 0x400
	sti
	push	0
	pop	es				/* es points to kernel */
	mov	(dev), dl			/* save disk */

.if boot_delay
	mov	dx, 5000
1:	mov	cx, -1; rep; lodsb
	dec	dx
	jne	1b
.endif

2:	mov	ah, 2
	int	0x16
	test	al, 8				/* alt pressed ? */
	je	1f
	call	pick_image
1:	incb	(errno)
	call	disk_setup
	incb	(errno)
	call	read_hdr
	incb	(errno)
	call	read_image
	xor	ax, ax
	mov	ds, ax
	mov	fs, ax
	mov	gs, ax
	cli
	mov	ss, ax
	mov	sp, mm.stack
	sti
	mov	ax, 2
	int	0x10				/* clear screen */
	mov	dl, (cs:dev)
	jmp	0, mm.image

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

pick_image:
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
	jae	error
	xor	ah, ah
	xchg	ax, bx				/* bx=digit, ax=number */
	mulb	(ten)
	add	bx, ax
	j	1b
1:	mov	(fs.image), bx			/* save inode */
	ret
ten:	.byte 10

read_hdr:					/* get imap, blkmap, itab */
	mov	ax, 0x0200 | [[fsheader_size-512]/512]
	mov	cx, 2
	mov	dl, (dev)
	xor	dh, dh
	mov	bx, mm.begin
	int	0x13
	jc	error
	ret

error:
	call	print; <\n\rboot failed (#>; errno: <0)\n\r\0>
	int	0x19

disk_setup:
	movb	(tries), boot_tries
1:	mov	ah, 8
	mov	dl, (dev)
	int	0x13
	jnc	1f
	dec	(tries)
	je	error
	j 	1b
1:	inc	dh
	mov	(heads), dh
	and	cl, 0x3f
	mov	(sectors), cl
	ret

read_image:
	mov	si, (fs.image)			/* get kernel's inode */
	sub	si, 0
	jc	error
	incb	(errno)
	shl	si, inode_log
	add	si, mm.inodes
	testb	*i.flags(es:si), 0x20
	jne	error				/* can't load large file */
	cmp	*i.size(es:si), 0
	je	error
	lea	si, *i.zones(si)
	mov	cx, 10
	mov	bx, mm.image
1:	seg es lodsw				/* read image */
	call	read_sector
	add	bx, 512
	loop	1b
1:	ret

print:
	pop	si
1:	lodsb
	test	al, al
	je	2f
	mov	ah, 0x0e
	mov	bx, 1
	int	0x10
	j 	1b
2:	jmp	si

dev: ..
sectors: ..
heads: ..
tries: ..

.if boot_debug
printn:
	pusha
	call	2f
	popa
	ret
2:	xor	dx, dx
	div	(cs:_ten)
	push	dx
	test	ax, ax
	je	1f
	call	2b
1:	pop	ax
	add	al, '0
	mov	ah, 0x0e
	int	0x10
	ret
_ten: 10
.endif
