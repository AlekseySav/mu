
	.text

	mov	ax, 0x0e30
	int	0x10

	sti
	sys	brk; end
	sys	open; hello; 0
	mov	bx, ax
	sys	read; buf; 10
	mov	bx, 1
	sys	write; buf; 10
	j .



	.data
hello: </home/hello.txt>

	.bss
buf: .=.+512
	end:
