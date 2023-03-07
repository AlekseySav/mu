objets = tools/boot.o mu.o \
	fs/bin/sh.o fs/bin/cat.o fs/bin/clear.o fs/bin/ls.o \
	fs/bin/echo.o fs/bin/stat.o fs/bin/touch.o fs/bin/\:.o \
	fs/bin/hexdump.o fs/bin/goto.o fs/bin/cmp.o \
	fs/bin/if.o

image.o: config.s tools/mkfs $(objets)
	@cat $^ >$@
	@tools/mkfs \
		/etc/boot=tools/boot.o \
		/etc/mu=mu.o +i \
		/bin/sh=fs/bin/sh.o +x \
		/bin/cat=fs/bin/cat.o +x \
		/bin/clear=fs/bin/clear.o +x \
		/bin/ls=fs/bin/ls.o +x \
		/bin/echo=fs/bin/echo.o +x \
		/bin/stat=fs/bin/stat.o +x \
		/bin/touch=fs/bin/touch.o +x \
		/bin/\:=fs/bin/\:.o +x \
		/bin/hexdump=fs/bin/hexdump.o +x \
		/bin/hex=fs/bin/hexdump.o +x \
		/bin/goto=fs/bin/goto.o +x \
		/bin/cmp=fs/bin/cmp.o +x \
		/bin/if=fs/bin/if.o +x \
		/1=fs/tmp/1.sh \
		/2=fs/tmp/2.sh \
		>$@

run: image.o
	@qemu-system-x86_64 -m 1 -display gtk,gl=on,grab-on-hover=off,zoom-to-fit=on --full-screen image.o 2>/dev/null
	@make -s clean
	@hexdump -C image.o >a

hex: image.o
	@hexdump -C $<
	@make -s clean

clean:
	@rm -f $(objets) config.s tools/mkfs


%.o: %.s
	@assem -x config.s syscalls.s $< >$@

config.s: tools/mkcfg tools/config.h
	@tools/mkcfg <tools/config.h >$@
