
all: chip8.srec chip8.wav hx20-logo.srec hx20-logo.wav

hx20-logo.srec: hx20-logo.ch8
	srec_cat hx20-logo.ch8 -binary -offset 0x1B00 -o hx20-logo.srec -motorola

hx20-logo.wav: hx20-logo.ch8 bin2hxwav
	./bin2hxwav hx20-logo.ch8 hx20-logo.wav 1B00 LOGO

chip8.srec: chip8.bin
	srec_cat chip8.bin -binary -offset 0x1000 -o chip8.srec -motorola

chip8.wav: chip8.bin bin2hxwav
	./bin2hxwav chip8.bin chip8.wav 1000 CHIP8

chip8.bin: chip8.asm
	dasm $^ -o$@ -f3 -l$(basename $^).lst

bin2hxwav: bin2hxwav.c
	gcc $^ -o $@ -Wall -Wextra

.PHONY: clean
clean:
	rm -f bin2hxwav *.wav *.srec *.bin *.lst

