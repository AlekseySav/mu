/ high memory allocator
/ mm.init()
/ mm.free(size: dx, seg: ax)			{ ax, dx }
/ mm.alloc(size: dx) -> seg: ax			{ dx }

MAX_ORDER = 11

	.sect	<.init>

mm.init:
	mov	ax, mm_end
	push	ax
	mov	$[1<<MAX_ORDER]/4, cx
	mov	$freelist, di
	mov	$-1, eax
	rep stosl				/ -1 = used
	pop	ax
	mov	$MAX_ORDER+1, cl
	xor	di, di
	sub	$128, ax			/ first 64k not used
	cmp	$1<<MAX_ORDER, ax
	jbe	1f
	mov	$1<<MAX_ORDER, ax
1:	dec	cl
	mov	$1, dx
	shl	cl, dx
	cmp	dx, ax
	jb	1b
	mov	cl, freelist(di)
	add	dx, di
	sub	dx, ax
	jne	1b
	ret

	.sect	<.text>

mm.free:
	call	mm.order
	shr	$5, ax
	sub	$128, ax
	push	bx
	push	cx
	push	dx
	mov	dl, cl
1:	mov	ax, bx
	mov	cl, freelist(bx)		/ free area
	mov	$1, dx
	shl	cl, dx
	xor	dx, bx				/ bx = compl buddy
	cmpb	cl, freelist(bx)
	jne	9f				/ not ready to merge
	not	dx
	and	dx, ax				/ ax = left buddy
	mov	ax, bx
	not	dx
	xor	dx, bx				/ bx = right buddy
	inc	cl
	cmp	$MAX_ORDER, cx
	je	9f
	movb	$-1, freelist(bx)
	jmp	1b
9:	pop	dx
	pop	cx
	pop	bx
	ret

mm.alloc:
	call	mm.order
	push	di
	push	si
	push	bx
	push	cx
	push	dx
	mov	$0f, bx
	mov	$freelist, si
1:	cmp	$freelist+[1<<MAX_ORDER], si
	je	2f
	lodsb
	cmp	dl, al
	jl	1b				/ used or too small
	cmp	(bx), al
	ja	1b
	lea	-1(si), bx
	jmp	1b
2:	cmp	$0f, bx
	je	error
1:	cmp	(bx), dl			/ too large block: split
	je	2f
	decb	(bx)
	mov	(bx), cl
	mov	$1, ax
	shl	cl, ax
	mov	(bx), cl
	add	ax, bx
	mov	cl, (bx)
	jmp	1b
2:	movb	$-1, (bx)			/ mark used
	lea	128-freelist(bx), ax
	shl	$5, ax				/ n. -> segment
	pop	cx				/ cl = power
	push	ax
	push	es
	mov	ax, es
	xor	di, di
	mov	$1, ax
	shl	cl, ax
	mov	ax, cx
	xor	ax, ax
	shl	$8, cx				/ sectors -> words
	rep stosw
	pop	es
	pop	ax
	pop	cx
	pop	bx
	pop	si
	pop	di
	ret

mm.order:
	push	ax
	mov	dx, ax
	xor	dx, dx
1:	test	ax, ax
	je	1f
	shr	$1, ax
	inc	dx
	jmp	1b
1:	/ dec	dx
	pop	ax
	ret

	.sect	<.data>

0:	.byte -1

	.sect	<.bss>

mm_end: .=.+2
freelist: .=.+[1<<MAX_ORDER]
