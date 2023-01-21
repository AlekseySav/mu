debug = 1

exit = 0
fork = 1
read = 2
write = 3
open = 4
close = 5
create = 6	/* Not implemented */
seek = 7
dup = 8
dup2 = 9
brk = 10
exec = 11	/* Not implemented */
alloc = 12
free = 13

N_PROC = 10
N_OPEN = 10
N_INODES = 512
N_ZONES = 512*8
TTY_SIZE = 128

	.struct
i.flags:	.=.+1				/* udl--rwx */
i.links:	.=.+1
i.size:		.=.+2
i.ctime:	.=.+4
i.mtime:	.=.+4
i.zones:	.=.+20
inode_size = 32
inode_log = 5

	.struct
f.mode:		.=.+1
f.links:	.=.+1
f.inode:	.=.+2
f.pos:		.=.+2
f.buf:		.=.+2
fp_size:
fp_log = 3

	.struct
dir.n:		.=.+2
dir.name:	.=.+14
dir_size:
dir_log = 4

	.struct
fs.boot:	.=.+508
fs.image:	.=.+2
fs.magic:	.=.+2
fs.blkmap:	.=.+[N_ZONES/8]
fs.inodes:	.=.+[inode_size*N_INODES]
fsheader_size:

	.struct
p.id:		.=.+2				/* pid 0=free */
p.ax:		.=.+2				/* syscall return value */
p.parent:	.=.+2
p.seg:		.=.+2
p.sp:		.=.+2				/* save sp for syscall */
p.root:		.=.+2
p.pwd:		.=.+2
p.brk:		.=.+2
p.fd:		.=.+[2*N_OPEN]
proc_size:
proc_log = 4

	.struct					/* first ~64K of mem */
		.=.+2048			/* IVT x BDA */
		.=.+2048
mm.stack:
mm.begin:
mm.blkmap:	.=.+[N_ZONES/8]
mm.inodes:	.=.+[32*N_INODES]
mm.image:

LOW_MEMORY = 0x5000
HIGH_MEMORY = 0x8000
N_BUFFERS = [HIGH_MEMORY-LOW_MEMORY]/32
