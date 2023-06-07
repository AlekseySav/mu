/ namei routine
/	used by open, creat, link, unlink, stat, etc.
/
/ in:
/  - filepath -> fs:si
/ out:
/  - inode -> dx
/  - parent inode = p.inum
/  - entry offset -> si
/	* if dx = 0, si points to first free entry, else to entry with inode=dx
/	* within parent directory
/  - parent fp -> bx
/	* if p.inum=0, bx is invalid
/
/ helper functions:
/ - namei_p -- verify parent directory exists
/ - namei_c -- verify current file exists
/

	.sect	<.text>

namei:
	push	ax
	push	cx
	push	bp
	push	di
	mov	current, bx
	mov	p.pwd(bx), dx			/ pwd inode
seg fs; mov	(si), al
	cmp	$'/, al
	jne	1f
	inc	si
	mov	$11, dx				/ root inode
1:
	xor	bx, bx
next_dir:
seg fs; lodsb
	cmp	$'/, al
	je	next_dir
seg fs; test	al, al
	je	9f
	dec	si
	mov	current, di
	mov	dx, p.inum(di)			/ save prev inode
	test	dx, dx
	je	9f				/ invalid parent, stop
	test	bx, bx
	je	1f
	push	dx
	call	fp.close
	pop	dx
1:	mov	dx, ax
	call	fp.openi
	mov	$-1, bp				/ offset
1:	push	si				/ save path
next_dirent:
	pop	si
	push	si
	mov	$16, cx
	call	fast_read
	jnc	1f
	call	fp.close			/ no such entry
	xor	dx, dx
2:
seg fs;	lodsb
	test	$-1, al
	je	8f
	cmp	$'/, al
	je	8f
	jmp	2b
1:	mov	(di), dx			/ save inode
	add	$2, di
	sub	$2, cx
	test	dx, dx				/ free entry -> bp ?
	jne	1f
	test	bp, bp
	jns	1f
	mov	f.pos(bx), bp
1:
seg fs;	lodsb
	test	$-1, al
	je	2f
	cmp	$'/, al
	je	2f
	scasb
	jne	next_dirent			/ not this entry
	loop	1b
2:						/ entry found
	mov	f.pos(bx), bp			/ entry -> bp
8:	dec	si				/ restore '/' or '\0'
	add	$2, sp				/ pop old path
	jmp	next_dir
9:	sub	$16, bp				/ normalize bp
	mov	bp, si
	pop	di
	pop	bp
	pop	cx
	pop	ax
	ret

namei_p:
	call	namei
	push	di
	mov	current, di
	test	$-1, p.inum(di)
	je	error
	pop	di
9:	ret

namei_c:
	call	namei_p
	test	dx, dx
	jne	9b
	call	fp.close
	jmp	error

/ for testing

0:	1f; 2f
1:	5*16
	11; <..>;    .fill 12
	11; <.>;     .fill 13
	12; <dev>;   .fill 11
	12; <bin>;   .fill 11
	12; <etc>;   .fill 11
2:	5*16
	11; <..>;    .fill 12
	12; <.>;     .fill 13
	2;  <tty>;   .fill 11
	3;  <stty1>; .fill 9
	4;  <stty2>; .fill 9

openi:
	sub	$11, ax
	push	di
	shl	$1, ax
	mov	ax, di
	mov	0b(di), di
	lea	2(di), ax
	mov	ax, f.buf(bx)
	pop	di
	ret

fast_read:
	mov	f.buf(bx), di
	mov	-2(di), ax
	cmp	f.pos(bx), ax
	ja	1f
	stc
	ret
1:	add	f.pos(bx), di
	add	cx, f.pos(bx)
	clc
	ret
