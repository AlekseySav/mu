tests = 1

tab_size = 8

N_OPEN = 16
N_PROC = 16
HZ = 100

PIC = 0x20
PIT = 0x40
DATA = 0x60
CMOS = 0x70
PIC2 = 0xa0
COM1 = 0x3f8
COM2 = 0x2f8
PCI = 0xcf8

.=0 / buf
buf.links:	.=.+2
buf.block:	.=.+2
buf.data:	.=.+516
buf_size:

.=0 / tty
tty.mode:	.=.+2
tty.buf:	.=.+2
tty.head:	.=.+2
tty.tail:	.=.+2
tty.line:	.=.+2
tty.n_sleeps:	.=.+1
tty.intr:	.=.+1
tty_size = 16
tty_log = 4

IEOF = 		0000001
ICANON =	0000002
ISIG =		0000004
ECHO =		0000010
ECHOE =		0000020
IVERIFY =	0000040
INOTAB =	0000100
ONLCR =		0000200
ICRNL =		0000400

.=0 / fp
f.mode:		.=.+1
f.links:	.=.+1
f.inode:	.=.+2
f.buf:		.=.+2
f.xzones:	.=.+2
f.pos:		.=.+4
f.inum:		.=.+2
fp_size = 16
fp_log = 4

.=0 / proc
p.id:		.=.+2
p.state:	.=.+1
p.counter:	.=.+1
p.parent:	.=.+2
p.break:	.=.+2
p.seg:		.=.+2
p.pwd:		.=.+2
p.fd:		.=.+2*N_OPEN
p.sp:		.=.+2
p.ax:		.=.+2
p.args:		.=.+6
p.childs:	.=.+1
p.flags:	.=.+1
p.sp2:		.=.+2
p.ttyp:		.=.+2
p.inum:		.=.+2
proc_size:

WAIT_CHILD	= 0001
WAIT_TTY	= 0002

PF_INTR		= 0001
PF_SYS		= 0040
PF_ERROR	= 0100
