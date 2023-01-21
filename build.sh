#!/bin/bash

assem -x config.s tools/boot.s tools/fs.s >.bin/boot.o
assem -x config.s mu.s tools/debug.s >.bin/m.o
cat .bin/boot.o .bin/m.o >image.o
truncate -s 8M image.o

qemu-system-x86_64 -display gtk,gl=on,grab-on-hover=off,zoom-to-fit=on --full-screen image.o 2>/dev/null
