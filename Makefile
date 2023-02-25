%.o: %.s
	@assem -x config.s $< >$@

config.s: tools/mkcfg tools/config.h
	@tools/mkcfg <tools/config.h >$@

image.o: config.s tools/mkfs tools/boot.o mu.o
	@cat $^ >$@
	@tools/mkfs \
		/etc/boot=tools/boot.o \
		/etc/mu=mu.o +i \
		/home/hello.txt=fs/hello.txt \
		>$@

run: image.o
	@qemu-system-x86_64 -display gtk,gl=on,grab-on-hover=off,zoom-to-fit=on --full-screen image.o 2>/dev/null
	@make -s clean

hex: image.o
	@hexdump -C $<
	@make -s clean

clean:
	@rm -f *.o tools/*.o config.s tools/mkfs
