	.fill 508+..-.; 6; 0xaa55

	.fill 10, -1				/* first 80 blocks reserved */
	.fill 502

	.fill inode_size, -1			/* first inode unused */

	.byte 0306, 1; 7*16; .fill 8; 34; .fill 18
	.byte 0306, 1; 5*16; .fill 8; 35; .fill 18
	.byte 0306, 1; 7*16; .fill 8; 36; .fill 18
	.byte 0306, 1; 2*16; .fill 8; 37; .fill 18
	.byte 0306, 1; 2*16; .fill 8; 38; .fill 18
	.byte 0206, 1; 3072; .fill 8; 41; 42; 43; 44; 45; 46; .fill 8
	.byte 0204, 1; 512;  .fill 8; 40; .fill 18
	.byte 0204, 1; 16; .fill 8; 39; .fill 18

	.fill inode_size*[N_INODES-9]

	1; <.\0\0\0\0\0\0\0\0\0\0\0\0\0>
	1; <..\0\0\0\0\0\0\0\0\0\0\0\0>
	2; <etc\0\0\0\0\0\0\0\0\0\0\0>
	3; <tmp\0\0\0\0\0\0\0\0\0\0\0>
	4; <bin\0\0\0\0\0\0\0\0\0\0\0>
	5; <home\0\0\0\0\0\0\0\0\0\0>
	.fill 512-[6*16]

	2; <.\0\0\0\0\0\0\0\0\0\0\0\0\0>
	1; <..\0\0\0\0\0\0\0\0\0\0\0\0>
	6; <munix\0\0\0\0\0\0\0\0\0>
	7; <init\0\0\0\0\0\0\0\0\0\0>
	8; <hello\0\0\0\0\0\0\0\0\0>
	.fill 512-[5*16]

	3; <.\0\0\0\0\0\0\0\0\0\0\0\0\0>
	1; <..\0\0\0\0\0\0\0\0\0\0\0\0>
	.fill 512-[2*16]

	4; <.\0\0\0\0\0\0\0\0\0\0\0\0\0>
	1; <..\0\0\0\0\0\0\0\0\0\0\0\0>
	.fill 512-[2*16]

	5; <.\0\0\0\0\0\0\0\0\0\0\0\0\0>
	1; <..\0\0\0\0\0\0\0\0\0\0\0\0>
	.fill 512-[2*16]

	<\nhello, world!\n\n>
	.fill 512-16

1:	mov	ax, cs
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	ss, ax
	sys	fork
	mov	(child), ax
	test	ax, ax
	jne	skip
	movb 	(hello), 'r
skip = .-1b
	mov	bx, 1
	sys	write; hello; 7
	mov	ax, (child)
	test	ax, ax
	jne	hang
	sys	exit
hang = .-1b
	j	.-1b
hello = .-1b; <hello!>
child = .-1b
	.fill	512+1b-.
