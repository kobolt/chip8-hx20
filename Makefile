
all: chip8.srec hx20-logo.srec

hx20-logo.srec: hx20-logo.ch8
	srec_cat hx20-logo.ch8 -binary -offset 0x1B00 -o hx20-logo.srec -motorola

chip8.srec: chip8.bin
	srec_cat chip8.bin -binary -offset 0x1000 -o chip8.srec -motorola

chip8.bin: chip8.asm
	dasm $^ -o$@ -f3 -l$(basename $^).lst

.PHONY: clean
clean:
	rm -f *.srec *.bin *.lst

