/ syscall & timer routine
/ intb, irq0, syscall, return, error

	.sect	<.init>

pit.init:
	mov	$0x36, al			/ 00-11-011-0
	outb	$PIT+3				/ ch 0, square, lsb/msb, binary
	mov	$[1193182/HZ]&0xff, al
	outb	$PIT
	mov	$[1193182/HZ]>>8, al
	outb	$PIT
	ret

	.sect	<.text>

intb:
	iret

irq0:
	push	$do_timer
	jmp	1f
syscall:
	push	$do_syscall
1:	cld
	pusha
	xor	ax, ax
	mov	ax, ds
	mov	ax, es
	mov	current, bx
	mov	$0, p.ax(bx)
	andb	$!PF_ERROR, p.flags(bx)
	mov	sp, p.sp(bx)
	mov	sp, bp
	call	16(bp)
return:
	mov	current, bx
7:	mov	p.seg(bx), ss
	mov	p.sp(bx), sp
	mov	sp, bp
	testb	$PF_SYS, p.flags(bx)
	je	1f				/ pending syscall?
	andb	$!PF_SYS, p.flags(bx)
	mov	p.sp2(bx), sp
	popa
	pop	fs
	ret
1:	cmp	$do_syscall, 16(bp)
	jne	3f
	andb	$![1<<6|1], 22(bp)		/ unset ZF, CF
	testb	$PF_ERROR, p.flags(bx)
	setne	dl
	test	$-1, p.ax(bx)
	jne	2f
	orb	$1<<6, 22(bp)			/ set ZF on ax=0
2:	orb	dl, 22(bp)			/ set CF on error
	mov	p.ax(bx), ax
	mov	ax, 14(bp)			/ return value
3:	mov	p.seg(bx), ax
	mov	ax, ds
	mov	ax, es
	mov	ax, 20(bp)			/ replace cs
	popa
	add	$2, sp
	iret

error:
	mov	current, bx
	orb	$PF_ERROR, p.flags(bx)
	jmp	7b

do_timer:
	incl	ticks
	testb	$-1, p.counter(bx)
	je	1f
	decb	p.counter(bx)
	jns	9f
1:	call	sched
9:	mov	$0x20, al
	outb	$PIC
	ret

do_syscall:
	mov	18(bp), si			/ get cs:ip -> fs:si
	mov	20(bp), fs
	seg	fs
	lodsb					/ call number
	cmp	$n_syscalls, ax
	jae	error
	shl	$2, ax
	lea	p.args(bx), di			/ dest -> di
	mov	ax, bx
	mov	systable(bx), cx		/ n. args -> cx
	seg	fs
	rep movsw
	mov	si, 18(bp)
	mov	systable+2(bx), ax		/ func -> ax
1:	mov	current, di
	mov	p.args+4(di), cx
	mov	p.args+2(di), si
	mov	p.args+0(di), bx
	jmp	ax

	.sect	<.bss>
ticks: .=.+4
