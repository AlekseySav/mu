/ rs232 i/o
/ rs.init()
/ rs1.put(char: al)				{ dx }
/ rs2.put(char: al)				{ dx }
/ irq3, irq4

	.sect	<.init>

rs.init:
	mov	$COM1, bx
	call	1f
	mov	$COM2, bx
1:	lea	1(bx), dx
	xor	al, al				/ disable interrupts
	outb
	lea	3(bx), dx
	mov	$0x80, al			/ DLAB
	outb
	lea	0(bx), dx
	mov	$1, al				/ 115200 bps
	outb
	xor	al, al
	inc	dx
	outb
	lea	3(bx), dx
	mov	$0x30, al			/ 8 bits, no parity, one stop bit
	outb
	lea	1(bx), dx
	mov	$0x01, al			/ read interrupt only
	outb
	lea	4(bx), dx
	mov	$0x0b, al			/ RTS, DTS, IRQ
	outb
	lea	2(bx), dx
	mov	$0x87, al			/ FIFO, clear, 8-byte threshold
	outb
	ret

	.sect	<.text>

rs2.put:
	mov	$COM2+5, dx
	jmp	rs.put
rs1.put:
	mov	$COM1+5, dx
rs.put:
	push	ax
1:	inb
	test	$0x20, al
	je	1b
	pop	ax
	sub	$5, dx
	outb
	ret

/ COM2
irq3:
	push	$8f
	jmp	1f
/ COM1
irq4:
	push	$7f
1:	cld
	pusha
	xor	ax, ax
	mov	ax, ds
	mov	ax, es
	mov	sp, bp
	mov	16(bp), bx
	mov	(bx), dx
	inb
	test	al, al
	je	1f
	mov	2(bx), bx
	call	tty.poll
1:	mov	$0x20, al
	outb	$PIC
	jmp	return

	.sect	<.data>

7:	COM1; 3
8:	COM2; 4
