/ usb driver
/ usb.init()
/ usb.rblk(buffer: di)				{ ax, dx }
/ usb.wblk(buffer: di)				{ ax, dx }

CAPLENGTH	= 0
RSVD		= 1
HCIVERSION	= 2
HCSPARAMS1	= 4
HCSPARAMS2	= 8
HCSPARAMS3	= 12
HCCPARAMS1	= 16
DBOFF		= 20
RTSOFF		= 24
HCCPARMS2	= 28

	.sect	<.init>

usb.init:
	cmp	$0x30, dh
	jne	9f				/ not XHCI
	mov	$5, al				/ BAR1
	call	pci.read
	test	eax, eax
	jne	9f
	mov	$4, al
	call	pci.read			/ BAR0
	and	$!10, al			/ <?>
	mov	eax, edi

	mov	CAPLENGTH(eax), al
	mov	eax, edx
	shr $16, edx
	b
	/ 08001040

	mov	$'!, al
	call	con.put
	jmp .
9:	ret

	.sect	<.bss>

usb.base: .=.+4
