. = 0

	.sect	<.init>

	intb; 0; ddbg; 0; intb; 0; intb; 0
	intb; 0; intb; 0; intb; 0; intb; 0
	irq0; 0; irq1; 0; intb; 0; irq3; 0
	irq4; 0; intb; 0; intb; 0; intb; 0
	syscall; 0

start:
	mov	$bss, di
	mov	$[0x10000-bss+3]/4, cx
	xor	eax, eax
	rep stosl				/ clear bss
	inb	$0x92
	or	$2, al
	outb	$0x92				/ enable A20 line
	call	rs.init
	pop	ax
	call	con.init
	call	tty.init
	pop	ax
	call	mm.init
	call	pit.init
	call	pci.init
	call	make_init_task
	mov	$start, di
	mov	$[1024-start]/4, cx
	mov	$intb, eax			/ prepare to set IVT
	jmp	go

	.sect	<.text>
	.fill	64				/ init stack
	.fill	1024-.
go:
	rep stosl				/ set IVT
	mov	current, bx
	mov	p.sp(bx), sp			/ set stack
	mov	p.seg(bx), ss
	sti
	push	$0x202				/ flags
	push	$..				/ cs
	push	$1024				/ ip
	jmp	irq0

	.sect	<.init>

make_init_task:
	call	proc.create
	mov	$3, dx
	call	mm.alloc
	mov	current, bx
	mov	$3, p.break(bx)
	mov	ax, p.seg(bx)
	mov	$1024, p.sp(bx)
	push	es
	mov	ax, es
	mov	$1024, di
	mov	$init_task, si
	mov	$512/4, cx
	rep movsl
	pop	es
	ret

init_task:
o=.; .=1024

.start:
	sys	intr; 0				/ disable interrupts
	sys	sttyp; 2			/ attach COM1 tty
	sys	open; ttym; 0			/ stdin
	sys	open; ttym; 1			/ stdout
	sys	dup; fd1			/ stderr
	sys	write; fd1; msg; 3
	mov	$0xe4, al			/ timer, keyboard, COM2, COM1
	outb	$PIC+1
	sti
	sys	fork
	je	.go				/ branch to child
	sys	rele
	jmp	.-3				/ release processor
.go:
	sys	fork
	je	1f
	sys	wait
	sys	write; fd1; msg; 3
1:
	sys	rele
	jmp	.-3

ttym: </dev/stty1\0>
msg: <hey>; fd0: 0; fd1: 1
i_end:

.=o+.-1024
