tries = 100
kernseg = 0x1000
. = 0x7c00

	jmp	1f; .byte 'u
	.fill	108
/ set up segments & flags
1:	cld
	ljmp	0, .+5
	xor	ax, ax
	mov	ax, ds
	cli
	mov	ax, ss
	mov	$.+512, sp
	sti
/ set up disk
	mov	dl, dev
	mov	$tries, cx
1:	mov	$8, ah
	int	$0x13
	jnc	1f
	loop	1b
	jmp	error
1:	inc	dh
	mov	dh, heads
	and	$0x3f, cl
	mov	cl, sectors
/ pass values to kernel
	int	$0x12
	shl	$1, ax
	mov	ax, n_buffers
	mov	$3, ah
	int	$0x10
	mov	dx, cursor
/ read image
	mov	$zones, si
	xor	bx, bx
	mov	$kernseg, ax
	mov	ax, es
1:	lodsw
	test	ax, ax
	js	9f				/ done
	call	read_sector
	add	$512, bx
	jmp	1b
9:
/ disable interrupts
	cli
	mov	$-1, al
	outb	$PIC+1
	outb	$PIC2+1
/ move image
	xor	si, si
	xor	di, di
	mov	size, cx
	xor	ax, ax
	mov	ax, es
	mov	$kernseg, ax
	mov	ax, ds
	rep movsl
/ set stack & segments
	xor	ax, ax
 	mov	ax, ds
 	mov	ax, es
	mov	ax, fs
	mov	ax, ss
	mov	$1024, sp
/ send parameters
	push	block
	push	n_blocks
	push	inode
	push	n_inodes
	push	n_buffers
	push	cursor
/ jump to kernel
	ljmp	0, 68

9:	ret
/ destroys di
read_sector:
	mov	$tries, di
1:	pusha
	xor	dx, dx
	div	sectors				/* ax = cyl x head, dx = sector - 1 */
	mov	dl, cl
	inc	cl				/* cl = sector */
	divb	heads				/* al = cylinder, ah = head */
	mov	ah, dh
	mov	al, ch
	mov	dev, dl
	mov	$0x0201, ax
	int	$0x13
	popa
	jnc	9b
	dec	di
	jne	1b

error:
	mov	$0x0e00|'E, ax
	int	$0x10
	jmp	.

dev: 0; heads: 0; sectors: 0
n_buffers: 0
cursor: 0

.=0x7c00+400
size:		.=.+2
zones:		.=.+2*12
block:		.=.+2
inode:		.=.+2
n_blocks:	.=.+2
n_inodes:	.=.+2
