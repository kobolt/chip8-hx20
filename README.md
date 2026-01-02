# CHIP-8 Interpreter for Epson HX-20
This project builds a [CHIP-8](https://en.wikipedia.org/wiki/CHIP-8) interpreter for the [Epson HX-20](https://en.wikipedia.org/wiki/Epson_HX-20) portable computer.

## Implementation Notes
* Behaves like the original CHIP-8 implementation without any "quirks".
* Passes relevant tests in the [chip8-test-suite](https://github.com/Timendus/chip8-test-suite).
* Graphics uses 64x32 pixels on the left side of the (120x32 pixel) LCD display.
* Keyboard layout same as many PC based CHIP-8 interpreters, using WASD, etc.
* Speaker beep works, but temporarily blocks execution.
* Timer (OCF) interrupt is not used since it interferes with keyboard scanning.
* The interpreter and CHIP-8 programs are loaded into memory with the built-in MONITOR.

## Demo Video
[Epson HX-20 CHIP-8 Interpreter](https://www.youtube.com/watch?v=qs1cFOF7RIY)

## Memory Map
| Start  | End    | Usage              |
| ------ | ------ | ------------------ |
| 0x1000 | 0x18FF | Interpreter Code   |
| 0x1900 | 0x1AFF | Interpreter Memory |
| 0x1B00 | 0x28FF | CHIP-8 Program     |

The memory area from 0x1900 to 0x28FF is seen as 0x000 to 0xFFF from within the CHIP-8 execution.

## Build
The [dasm](https://dasm-assembler.github.io/) macro assembler is required.
The [SRecord](https://srecord.sourceforge.net/) software is used to convert files to S-records.
Just run make:
```
make
```

## Testing in an Emulator
Use the [hex20](https://github.com/kobolt/hex20) emulator to test.
Only a single S-record can be loaded, so just concatenate the interpreter with the CHIP-8 program, e.g.:
```sh
cat chip8.srec hx20-logo.srec > chip8-hx20-logo.srec
hex20 -s chip8-hx20-logo.srec
```
Start execution after loading the S-record into the MONITOR by typing:
```
G1000
```

### Emulator Keyboard Issue
The default time in hex20 that the keys are "held down" on the keyboard is too short for the interpreter to properly detect.
This can be somewhat alleviated by increasing this constant from 500 to 10000 and recompiling hex20:
```
#define CONSOLE_KEYBOARD_RELEASE 10000
```

## Transfer to a Real Epson HX-20
One method is to use the external cassette interface by playing audio files from a PC. The hex20 emulator can be used to convert an S-record to a WAV file.

### Interpreter WAV File
Start the emulator with the S-record as an argument:
```sh
hex20 -s chip8.srec
```
Once S-record loading has finished, from the MONITOR type:
```
A
1000
18FF
/
```
Enter the debugger with Ctrl+C and type:
```
f chip8.wav
c
```
From the MONITOR type:
```
W C,CHIP8.BIN
```
Once "Ok" appears, enter the debugger again and quit with 'q'. The file "chip8.wav" has been created.

### HX-20 Logo Test Program WAV File
Start the emulator with the S-record as an argument:
```sh
hex20 -s hx20-logo.srec
```
Once S-record loading has finished, from the MONITOR type:
```
A
1B00
1CFF
/
```
Enter the debugger with Ctrl+C and type:
```
f hx20-logo.wav
c
```
From the MONITOR type:
```
W C,LOGO.BIN
```
Once "Ok" appears, enter the debugger again and quit with 'q'. The file "hx20-logo.wav" has been created.

### Loading on an Epson HX-20
Connect an audio cable from a PC to the "Ear" input.
Enter the MONITOR and type:
```
A
1000
18FF
/
R C,*.*
```
Play back the "chip8.wav" file from the PC to load the interpreter.
Once "Ok" appears, type:
```
A
1B00
1CFF
/
R C,*.*
```
Play back the "hx20-logo.wav" file from the PC to load that CHIP-8 program.
Note that the second parameter to the "A" command is the end location and dependent on the program size, so it may change with other programs.
Once "Ok" appears, start execution:
```
G1000
```

It is possible to abort the ongoing CHIP-8 execution with the "MENU" button. At that point another CHIP-8 program can be loaded from the MONITOR again. It is not necessary to re-load the interpreter since the HX-20 retains the memory.

