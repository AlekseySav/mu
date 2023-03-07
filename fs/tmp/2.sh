if $# != 0002; goto usage
if $1 == make; goto make

: default
s; echo /bin/$0; q

: usage
echo "  usage: sh" $0 "<arg>"; q

: make
echo "  compiling..."; q
