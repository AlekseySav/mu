/ PCI driver
/ pci.init()

	.sect	<.init>

.bus:	.word	0
.dev:	.word	0
.func:	.word	0

pci.read:
	push	edx
	mov	$1<<31, edx
	xor	ah, ah
	shl	$2, ax
	or	ax, dx				/ offset
	mov	.func, ax
	shl	$8, ax
	cwde
	or	eax, edx			/ func
	mov	.dev, ax
	shl	$11, ax
	or	eax, edx			/ slot
	mov	.bus, ax
	shl	$16, eax
	or	eax, edx			/ bus
	mov	edx, eax
	mov	$PCI, dx
	outl
	add	$4, dl
	inl
	pop	edx
	ret

pci.init:
1:	movb	$0, .dev
2:	movb	$0, .func
	mov	$3, al
	call	pci.read
	shr	$16, eax
	mov	ax, dx				/ header type, etc.
3:	push	dx
	xor	al, al
	call	pci.read
	cmp	$-1, ax				/ vendor id
	je	4f
	mov	$2, al
	call	pci.read			/ class, subclass, prog-if
	mov	ax, dx
	shr	$16, eax
	mov	$pci.tab, di
	mov	$[9f-pci.tab]/4, cx
6:	scasw
	je	7f
	scasw
	loop	6b
	jmp	4f
7:	call	(di)
4:	pop	dx
	test	$0x80, dx			/ multi-function?
	je	5f
	incb	.func
	cmpb	$8, .func
	jne	3b
5:	incb	.dev
	cmpb	$32, .dev
	jne	2b
	incb	.bus
	cmpb	$-1, .bus
	jne	1b
	ret

	.align	2

pci.tab:
	0x0c03;	usb.init
9:
