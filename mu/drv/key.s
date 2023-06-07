/ keyboard -- char input device
/ key.get() -> char: al

	.sect	<.text>

irq1:
	cld
	sub	$2, sp
	pusha
	xor	ax, ax
	mov	ax, ds
	mov	ax, es
	inb	$DATA
	mov	al, dl				/ save sign
	and	$0x7f, al
	cmp	$key.len, al
	jae	9f
	mov	key.mode, bx
	mov	key.tab(bx), bx
	xlat
	test	al, al
	js	1f
	test	dl, dl
	js	9f
	mov	$2, bx
	call	tty.poll
9:	mov	$0x20, al
	outb	$PIC
	jmp	return

1:	and	$0x7f, al
	test	dl, dl
	js	1f
	or	al, key.mode			/ control key down
	jmp	9b
1:	not	al
	and	al, key.mode			/ control key up
	jmp	9b

	.sect	<.bss>

key.mode: .=.+2

	.sect	<.data>
key.tab: 1f; 2f; 3f; 1f
1:	<\0\e1234567890-=\b\t>			/* default */
	<qwertyuiop[]\n>; .byte 0x82
	<asdfghjkl;'`>; .byte 0x84
	<\\zxcvbnm,./>; .byte 0x84
	<*\0 \0>				/* alt capslock unused */
2:	<\0\e1234567890-=\b\t>			/* ctrl */
	.byte 'Q-'@, 'W-'@, 'E-'@, 'R-'@, 'T-'@, 'Y-'@
	.byte 'U-'@, 'I-'@, 'O-'@, 'P-'@, '[-'@, ']-'@, '\n, 0x82
	.byte 'A-'@, 'S-'@, 'D-'@, 'F-'@, 'G-'@, 'H-'@
	.byte 'J-'@, 'K-'@, 'L-'@, ';, '', '`, 0x84
	.byte '\\-'@, 'Z-'@, 'X-'@, 'C-'@, 'V-'@, 'B-'@, 'N-'@, 'M-'@; <,./>
	.byte 0x84; <*\0 \0>			/* alt capslock unused */
3:	<\0\e!@#$%^&*()_+\b\t>			/* shift */
	<QWERTYUIOP{}\n>; .byte 0x82
	<ASDFGHJKL:"~>; .byte 0x84
	<|ZXCVBNM<\>?>; .byte 0x84
key.len = 2b-1b
