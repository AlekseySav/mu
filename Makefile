objets = tools/boot.o mu.o fs/sh.o fs/cat.o fs/clear.o fs/ls.o fs/echo.o fs/stat.o

image.o: config.s tools/mkfs $(objets)
	@cat $^ >$@
	@tools/mkfs \
		/home/hello.txt=fs/hello.txt \
		/etc/boot=tools/boot.o \
		/etc/mu=mu.o +i \
		/bin/sh=fs/sh.o +x \
		/bin/cat=fs/cat.o +x \
		/bin/clear=fs/clear.o +x \
		/bin/ls=fs/ls.o +x \
		/bin/echo=fs/echo.o +x \
		/bin/stat=fs/stat.o +x \
		>$@

run: image.o
	@qemu-system-x86_64 -m 1 -display gtk,gl=on,grab-on-hover=off,zoom-to-fit=on --full-screen image.o 2>/dev/null
	@make -s clean
	@hexdump -C image.o >a

hex: image.o
	@hexdump -C $<
	@make -s clean

clean:
	@rm -f [!i]*.o tools/*.o fs/*.o config.s tools/mkfs


%.o: %.s
	@assem -x config.s syscalls.s $< >$@

config.s: tools/mkcfg tools/config.h
	@tools/mkcfg <tools/config.h >$@
