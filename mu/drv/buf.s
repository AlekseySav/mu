/ buffers
/ buf.init()
/ buf.free(&buf: di)				{ ax, dx }
/ buf.mmap(&buf: di, block: dx)	-> buf: di
/ buf.alloc(&buf: di) -> buf: di		{ dx }

BUFFER_START = [end+buf_size-1]/buf_size*buf_size
BUFFER_COUNT = [0x10000-BUFFER_START]/buf_size

	.sect	<.text>

buf.free:
	test	$-1, (di)
	je	8f				/ detached buffer
	xor	ax, ax
	xor	dx, dx
	xchg	ax, (di)
	div	bufsize
	mul	bufsize				/ align buffer
	push	bx
	mov	ax, bx
	decb	buf.links(bx)
	jne	9f
	cmp	$-1, buf.block(bx)
	je	9f
	/ flush buffer
9:	pop	bx
8:	ret

buf.mmap1:
	mov	$-1, dx
buf.mmap:
	test	$-1, (di)			/ already mapped ?
	je	1f
	mov	(di), di
	cmp	buf.block(di), dx
	je	9f
	/ flush buffer
	/ fetch buffer
9:	ret
1:	push	bx
	push	cx
	push	di
	xor	bx, bx
	mov	$BUFFER_START, di
	mov	$BUFFER_COUNT, cx
1:	testb	$-1, buf.links(di)
	jne	2f				/ br. if not empty
	test	bx, bx
	jne	6f
	mov	di, bx
	cmp	$-1, dx
	jne	6f
	jmp	7f				/ done if no block
2:	cmp	dx, buf.block(di)
	jne	6f
	cmp	$-1, dx
	jne	8f				/ same block found
6:	add	$buf_size, di			/ continue
	loop	1b
	test	bx, bx
	jne	7f
	jmp	error				/ out of memory
7:	mov	bx, di
	mov	dx, buf.block(di)
	cmp	$-1, dx
	je	8f
	/ fetch buffer
8:	incb	buf.links(di)
	pop	bx
	add	$buf.data, di			/ adjust pointer
	mov	di, (bx)			/ store buffer
	pop	cx
	pop	bx
	ret

	.sect	<.data>

bufsize: buf_size
