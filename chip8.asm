	processor hd6303

; Configuration:
CHIP8_MEM_OFFSET equ $19 ; High-byte offset to CHIP-8 memory from real memory.

; Kernel routines:
DSPLCN   equ $FF49
SOUND    equ $FF64
KEYSCN   equ $FF6A

; Kernel variables:
NEWKTB   equ $0145

; Hardware registers:
FRC_HI   equ $09
LCDSEL   equ $26
LCDDAT   equ $2A
GATEB    equ $28
RTC_SEC  equ $40
RTC_MIN  equ $42
P26FB    equ $4F

	org $1000 ; Run from HX-20 RAM.
; Program:
start:
	; Set initial register values:
	ldd #(CHIP8_MEM_OFFSET * $100) + $200
	std pc
	ldd #0
	std i
	clr sp
	clr dt
	clr st
	clr timer
	ldx #v
	ldaa #16
clear_v_loop
	stab 0,x
	inx
	deca
	bne clear_v_loop

	; Always clear screen and mirror:
	jsr clear_screen

	; Copy font data into CHIP-8 memory space:
	clrb
	ldx #font_0
font_copy:
	ldaa 0,x
	pshx
	ldx #CHIP8_MEM_OFFSET * $100
	abx
	staa 0,x
	pulx
	inx
	incb
	cmpb #80 ; All font data bytes: 16 * 5
	bne font_copy

fetch:
	; Decrement timers:
	ldaa FRC_HI
	ldab timer
	sba
	cmpa #$28
	blt timer_skip
	tst dt
	beq timer_bt_skip
	dec dt
timer_bt_skip:
	tst st
	beq timer_st_skip
	ldaa #$0D
	ldab #1
	jsr SOUND
	dec st
timer_st_skip:
	ldab FRC_HI
	stab timer
timer_skip:

	; Load next instruction:
	ldx pc
	ldd 0,x

	; Store opcode values for later use:
	staa op1
	stab op2

	; Filter first nibble from first stored opcode:
	ldx #op1
	dc.b $61,$0F,$00 ; aim #$0F,0,x (Not supported in dasm!)

	; Use first nibble in a jump table:
	tab
	andb #$F0
	lsrb
	lsrb
	ldx #jump_table
	abx
	jmp 0,x
	; Entries are spaced by 4 bytes:
jump_table:
	jmp in_0
	dc.b 0
	jmp in_1_jp
	dc.b 0
	jmp in_2_call
	dc.b 0
	jmp in_3_se_v_imm
	dc.b 0
	jmp in_4_sne_v_imm
	dc.b 0
	jmp in_5_se_v_v
	dc.b 0
	jmp in_6_ld_v_imm
	dc.b 0
	jmp in_7_add_v_imm
	dc.b 0
	jmp in_8
	dc.b 0
	jmp in_9_sne_v_v
	dc.b 0
	jmp in_a_ld_i_imm
	dc.b 0
	jmp in_b_jp_v0
	dc.b 0
	jmp in_c_rnd
	dc.b 0
	jmp in_d_drw
	dc.b 0
	jmp in_e
	dc.b 0
	jmp in_f

in_0:
	ldaa op2
	cmpa #$E0
	beq in_0_cls
	cmpa #$EE
	beq in_0_ret
	; Unhandled 0x0 instruction:
	jmp panic

in_0_cls:
	jsr clear_screen
	jmp increment_pc

in_0_ret:
	; Get PC from top of stack:
	ldx #stack
	ldab sp
	abx
	ldaa 0,x
	ldab 1,x
	std pc
	; Decrement stack pointer:
	dec sp
	dec sp
	jmp fetch

in_1_jp:
	ldaa op1
	ldab op2
	ldx #pc
	adda #CHIP8_MEM_OFFSET
	staa 0,x
	stab 1,x
	jmp fetch

in_2_call:
	; Increment stack pointer:
	inc sp
	inc sp
	; Put PC at top of stack:
	ldx #stack
	ldab sp
	abx
	ldd pc
	addd #2
	staa 0,x
	stab 1,x
	; Jump to immediate address:
	ldaa op1
	ldab op2
	ldx #pc
	adda #CHIP8_MEM_OFFSET
	staa 0,x
	stab 1,x
	jmp fetch

in_3_se_v_imm:
	ldaa op2
	ldab op1
	ldx #v
	abx
	ldab 0,x
	cba
	bne in_3_se_v_imm_no_skip
	ldd pc
	addd #2
	std pc
in_3_se_v_imm_no_skip:
	jmp increment_pc

in_4_sne_v_imm:
	ldaa op2
	ldab op1
	ldx #v
	abx
	ldab 0,x
	cba
	beq in_4_sne_v_imm_no_skip
	ldd pc
	addd #2
	std pc
in_4_sne_v_imm_no_skip:
	jmp increment_pc

in_5_se_v_v:
	ldab op1
	ldx #v
	abx
	ldaa 0,x
	staa tmp
	ldab op2
	lsrb
	lsrb
	lsrb
	lsrb
	ldx #v
	abx
	ldab 0,x
	ldaa tmp
	cba
	bne in_5_se_v_v_no_skip
	ldd pc
	addd #2
	std pc
in_5_se_v_v_no_skip:
	jmp increment_pc

in_6_ld_v_imm:
	ldaa op2
	ldab op1
	ldx #v
	abx
	staa 0,x
	jmp increment_pc

in_7_add_v_imm:
	ldaa op2
	ldab op1
	ldx #v
	abx
	ldab 0,x
	aba
	staa 0,x
	jmp increment_pc

in_8:
	; Prepare index in X common for all 0x8 instructions:
	ldab op2
	lsrb
	lsrb
	lsrb
	lsrb
	ldx #v
	abx
	; Compare fourth nibble for final instruction:
	ldaa op2
	anda #$0F
	cmpa #$0
	bne in_f_not_0
	jmp in_8_0_ld_v_v
in_f_not_0:
	cmpa #$1
	bne in_f_not_1
	jmp in_8_1_or_v_v
in_f_not_1:
	cmpa #$2
	bne in_f_not_2
	jmp in_8_2_and_v_v
in_f_not_2:
	cmpa #$3
	bne in_f_not_3
	jmp in_8_3_xor_v_v
in_f_not_3:
	cmpa #$4
	bne in_f_not_4
	jmp in_8_4_add_v_v
in_f_not_4:
	cmpa #$5
	bne in_f_not_5
	jmp in_8_5_sub_v_v
in_f_not_5:
	cmpa #$6
	bne in_f_not_6
	jmp in_8_6_shr_v
in_f_not_6:
	cmpa #$7
	bne in_f_not_7
	jmp in_8_7_subn_v_v
in_f_not_7:
	cmpa #$e
	bne in_f_not_e
	jmp in_8_e_shl_v
in_f_not_e:
	; Unhandled 0x8 instruction:
	jmp panic

in_8_0_ld_v_v:
	ldaa 0,x
	ldab op1
	ldx #v
	abx
	staa 0,x
	jmp increment_pc

in_8_1_or_v_v:
	ldaa 0,x
	staa tmp
	ldab op1
	ldx #v
	abx
	ldaa 0,x
	oraa tmp
	staa 0,x
	clr vf
	jmp increment_pc

in_8_2_and_v_v:
	ldaa 0,x
	staa tmp
	ldab op1
	ldx #v
	abx
	ldaa 0,x
	anda tmp
	staa 0,x
	clr vf
	jmp increment_pc

in_8_3_xor_v_v:
	ldaa 0,x
	staa tmp
	ldab op1
	ldx #v
	abx
	ldaa 0,x
	eora tmp
	staa 0,x
	clr vf
	jmp increment_pc

in_8_4_add_v_v:
	ldaa 0,x
	staa tmp
	ldab op1
	ldx #v
	abx
	ldaa 0,x
	adda tmp
	bcs in_8_4_add_v_v_carry
	staa 0,x
	clr vf
	bra in_8_4_add_v_v_done
in_8_4_add_v_v_carry:
	staa 0,x
	ldab #1
	stab vf
in_8_4_add_v_v_done:
	jmp increment_pc

in_8_5_sub_v_v:
	ldaa 0,x
	staa tmp
	ldab op1
	ldx #v
	abx
	ldaa 0,x
	cmpa tmp ; Carry set if first register >= second register.
	bge in_8_5_sub_v_v_carry
	suba tmp
	staa 0,x
	clr vf
	bra in_8_5_sub_v_v_done
in_8_5_sub_v_v_carry:
	suba tmp
	staa 0,x
	ldab #1
	stab vf
in_8_5_sub_v_v_done:
	jmp increment_pc

in_8_6_shr_v:
	ldaa 0,x
	staa tmp
	ldab op1
	ldx #v
	abx
	ldaa tmp
	lsra
	bcs in_8_6_shr_v_carry
	staa 0,x
	clr vf
	bra in_8_6_shr_v_done
in_8_6_shr_v_carry:
	staa 0,x
	ldab #1
	stab vf
in_8_6_shr_v_done:
	jmp increment_pc

in_8_7_subn_v_v:
	ldaa 0,x
	staa tmp
	ldab op1
	ldx #v
	abx
	ldab 0,x
	ldaa tmp
	cmpb tmp ; Carry set if second register >= first register.
	ble in_8_7_subn_v_v_carry
	sba
	staa 0,x
	clr vf
	bra in_8_7_subn_v_v_done
in_8_7_subn_v_v_carry:
	sba
	staa 0,x
	ldab #1
	stab vf
in_8_7_subn_v_v_done:
	jmp increment_pc

in_8_e_shl_v:
	ldaa 0,x
	staa tmp
	ldab op1
	ldx #v
	abx
	ldaa tmp
	lsla
	bcs in_8_e_shl_v_carry
	staa 0,x
	clr vf
	bra in_8_e_shl_v_done
in_8_e_shl_v_carry:
	staa 0,x
	ldab #1
	stab vf
in_8_e_shl_v_done:
	jmp increment_pc

in_9_sne_v_v:
	ldab op1
	ldx #v
	abx
	ldaa 0,x
	staa tmp
	ldab op2
	lsrb
	lsrb
	lsrb
	lsrb
	ldx #v
	abx
	ldab 0,x
	ldaa tmp
	cba
	beq in_9_sne_v_v_no_skip
	ldd pc
	addd #2
	std pc
in_9_sne_v_v_no_skip:
	jmp increment_pc

in_a_ld_i_imm:
	ldaa op1
	ldab op2
	std i
	jmp increment_pc

in_b_jp_v0:
	ldaa op1
	ldab op2
	ldx #pc
	adda #CHIP8_MEM_OFFSET
	staa 0,x
	stab 1,x
	ldx #v
	ldab 0,x
	ldx pc
	abx
	stx pc
	jmp fetch

in_c_rnd:
	; Use FRC and RTC to get a random number:
	ldaa FRC_HI
	adda RTC_SEC
	eora #$FF
	adda RTC_MIN
	anda op2
	ldab op1
	ldx #v
	abx
	staa 0,x
	jmp increment_pc

in_d_drw:
	; Get size from fourth nibble into A:
	ldaa op2
	anda #$0F

	; Get Y-draw start from third nibble:
	ldab op2
	lsrb
	lsrb
	lsrb
	lsrb
	ldx #v
	abx
	ldab 0,x
	andb #$1F ; Wrap Y-draw start on 32.
	stab drw_y

	; Draw all Y rows:
	clr drw_c
	clr drw_i
in_d_drw_y:
	psha
	jsr in_d_drw_row
	pula
	inc drw_y ; Increment Y draw position.
	inc drw_i ; Increment memory index.
	deca ; Loop as long as size is > 0.
	bne in_d_drw_y

	; Set VF flag if spire collision occured:
	ldaa drw_c
	anda #1
	staa vf

	; Wait for one timer cycle to pass:
	ldab timer
in_d_drw_wait_timer
	ldaa FRC_HI
	sba
	cmpa #$28
	blt in_d_drw_wait_timer
	jmp increment_pc

	; Subroutine for drawing one line:
in_d_drw_row:
	; Get row pixel data from CHIP-8 memory via I register:
	ldx #i
	ldaa 0,x
	adda #CHIP8_MEM_OFFSET
	ldab 1,x
	xgdx ; Memory address now in X.
	ldab drw_i
	abx ; Add memory index to address in X.
	ldaa 0,x
	staa drw_d ; Store row pixel data back to memory.

	; Get X-draw start from second nibble:
	ldab op1
	ldx #v
	abx
	ldab 0,x
	andb #$3F ; Wrap X-draw start on 64.
	stab drw_x

	; Draw all X columns:
	clr drw_j
	ldaa #8
in_d_drw_x:
	staa drw_j
	psha
	jsr in_d_drw_pixel
	pula
	inc drw_x ; Increment X draw position.
	deca ; Loop for 8 rounds.
	bne in_d_drw_x
	rts

	; Subroutine for drawing one pixel:
in_d_drw_pixel:
	; Return if draw is attempted outside screen area:
	ldab drw_y
	cmpb #32 ; Skip if Y draw position is outside lowest part of screen.
	bge in_d_drw_pixel_rts
	ldab drw_x
	cmpb #64 ; Skip if X draw position is outside right part of screen.
	bge in_d_drw_pixel_rts
	bra in_d_drw_pixel_no_rts
in_d_drw_pixel_rts:
	rts
in_d_drw_pixel_no_rts:

	; Find LCD number (9 to 14) based on draw position:
	ldaa #9
	ldab drw_y
	cmpb #16
	blt in_d_drw_pixel_lcd_no_y
	adda #3
in_d_drw_pixel_lcd_no_y:
	ldab drw_x
	cmpb #40
	blt in_d_drw_pixel_lcd_no_x
	inca
in_d_drw_pixel_lcd_no_x:
	; Disable interrupts (from the keyboard) while using the LCD:
	sei

	ldab P26FB
	andb #$10 ; Preserve keyboard IRQ mask when updating LCDSEL.
	aba
	staa LCDSEL

	; Find LCD column (0x80->0xA7, 0xC0->0xE7) based on draw position:
	ldab drw_y
	cmpb #24
	bge in_d_drw_pixel_col_c0
	cmpb #8
	blt in_d_drw_pixel_col_80
	cmpb #16
	blt in_d_drw_pixel_col_c0
in_d_drw_pixel_col_80:
	ldaa #$80
	jmp in_d_drw_pixel_col_check_x
in_d_drw_pixel_col_c0:
	ldaa #$C0
in_d_drw_pixel_col_check_x:
	ldab drw_x
	cmpb #40
	blt in_d_drw_pixel_col_nosub_40
	subb #40
in_d_drw_pixel_col_nosub_40:
	aba

	; Set LCD column:
	staa LCDDAT
in_d_drw_pixel_busy_col:
	tst GATEB
	bpl in_d_drw_pixel_busy_col
	ldx LCDDAT ; Clock LCD SCK signal 4 times.
	ldx LCDDAT
	ldx LCDDAT
	ldx LCDDAT

	; Check if pixel should be set or cleared:
	ldab drw_d
	ldaa drw_j
	deca ; Subtract one, since it counts from 8 to 1.
	beq in_d_drw_pixel_data_no_shift
in_d_drw_pixel_data_shift:
	lsrb
	deca
	bne in_d_drw_pixel_data_shift
in_d_drw_pixel_data_no_shift:
	andb #1 ; Pixel value (1 or 0) now in B.
	stab tmp

	; Find byte location in screen mirror:
	ldaa drw_y
	lsla
	lsla
	lsla
	ldab drw_x
	lsrb
	lsrb
	lsrb
	aba
	tab
	ldx #screen
	abx ; Mirrored byte address prepared in X.

	; Shift the pixel value into correct bit position:
	ldaa tmp
	ldab drw_x
	andb #7 ; Mirrored bit number now in B.
	beq in_d_drw_pixel_xor_no_shift
in_d_drw_pixel_xor_shift:
	lsla
	decb
	bne in_d_drw_pixel_xor_shift
in_d_drw_pixel_xor_no_shift:
	staa tmp ; A now contains the bit shifted.

	; Store information about current pixel for collision check:
	ldab 0,x ; Retrieve mirrored byte.
	andb tmp
	stab tmp2

	; Do the XOR operation on the mirror:
	ldab 0,x ; Retrieve mirrored byte.
	eorb tmp
	stab 0,x ; Store mirrored byte.

	; Unshift the XOR'ed byte back to be displayed:
	ldaa drw_x
	anda #7 ; Mirrored bit number now in B.
	beq in_d_drw_pixel_xor_no_unshift
in_d_drw_pixel_xor_unshift:
	lsrb
	lsr tmp2
	deca
	bne in_d_drw_pixel_xor_unshift
in_d_drw_pixel_xor_no_unshift:
	andb #1

	; Update collision flag if pixel was unset:
	ldaa tmp2
	anda #1
	oraa drw_c
	staa drw_c

	; Set A to 0x20 (Pixel Clear) or 0x40 (Pixel Set) based on B:
	ldaa #$20
	tstb
	beq in_d_drw_pixel_data_clear
	adda #$20
in_d_drw_pixel_data_clear:

	; Find LCD row (0x20,24,28,2C,30,34,38) based on draw position:
	ldab drw_y
in_d_drw_pixel_row_cmp_again:
	cmpb #8
	blt in_d_drw_pixel_row_nosub_8
	subb #8
	jmp in_d_drw_pixel_row_cmp_again
in_d_drw_pixel_row_nosub_8:
	lslb
	lslb
	aba ; Row base address now in A.

	; Set LCD row (with pixel data):
	staa LCDDAT
in_d_drw_pixel_busy_row:
	tst GATEB
	bpl in_d_drw_pixel_busy_row
	ldx LCDDAT ; Clock LCD SCK signal 4 times.
	ldx LCDDAT
	ldx LCDDAT
	ldx LCDDAT

	; Re-enable interrupts:
	cli
	rts

in_e:
	; Compare third and fourth nibbles for final instruction:
	ldaa op2
	cmpa #$9E
	bne in_e_not_9e
	jmp in_e_9e_skp_v
in_e_not_9e:
	cmpa #$A1
	bne in_e_not_a1
	jmp in_e_a1_sknp_v
in_e_not_a1:
	; Unhandled 0xE instruction:
	jmp panic

in_e_9e_skp_v:
	ldx #v
	ldab op1
	abx
	ldab 0,x
	jsr is_key_pressed
	tsta
	bne in_e_9e_skp_v_no_key
	ldd pc
	addd #2
	std pc
in_e_9e_skp_v_no_key:
	jmp increment_pc

in_e_a1_sknp_v:
	ldx #v
	ldab op1
	abx
	ldab 0,x
	jsr is_key_pressed
	tsta
	beq in_e_a1_sknp_v_done
in_e_a1_sknp_v_no_key:
	ldd pc
	addd #2
	std pc
in_e_a1_sknp_v_done:
	jmp increment_pc

in_f:
	; Compare third and fourth nibbles for final instruction:
	ldaa op2
	cmpa #$65
	bne in_f_not_65
	jmp in_f_65_ld_v_i
in_f_not_65:
	cmpa #$55
	bne in_f_not_55
	jmp in_f_55_ld_i_v
in_f_not_55:
	cmpa #$33
	bne in_f_not_33
	jmp in_f_33_ld_b_v
in_f_not_33:
	cmpa #$29
	bne in_f_not_29
	jmp in_f_29_ld_f_v
in_f_not_29:
	cmpa #$1e
	bne in_f_not_1e
	jmp in_f_1e_add_i_v
in_f_not_1e:
	cmpa #$18
	bne in_f_not_18
	jmp in_f_18_ld_st_v
in_f_not_18:
	cmpa #$15
	bne in_f_not_15
	jmp in_f_15_ld_dt_v
in_f_not_15:
	cmpa #$0a
	bne in_f_not_0a
	jmp in_f_0a_ld_v_k
in_f_not_0a:
	cmpa #$07
	bne in_f_not_07
	jmp in_f_07_ld_v_dt
in_f_not_07:
	; Unhandled 0xF instruction:
	jmp panic

in_f_65_ld_v_i:
	ldaa op1
	staa tmp
in_f_65_ld_v_i_loop:
	; Get data from CHIP-8 memory via I register:
	ldx #i
	ldaa 0,x
	adda #CHIP8_MEM_OFFSET
	ldab 1,x
	xgdx
	ldab tmp
	abx
	ldaa 0,x
	; Store in V register:
	ldx #v
	ldab tmp
	abx
	staa 0,x
	; Loop as long as there are registers left:
	dec tmp
	bpl in_f_65_ld_v_i_loop ; Flips to negative when decrementing 0.
	; Increment I register:
	ldab op1
	addb #1
	ldx i
	abx
	stx i
	jmp increment_pc

in_f_55_ld_i_v:
	ldaa op1
	staa tmp
in_f_55_ld_i_v_loop:
	; Get data from V register:
	ldx #v
	ldab tmp
	abx
	ldaa 0,x
	staa tmp2
	; Store data in CHIP-8 memory via I register:
	ldx #i
	ldaa 0,x
	adda #CHIP8_MEM_OFFSET
	ldab 1,x
	xgdx
	ldab tmp
	abx
	ldaa tmp2
	staa 0,x
	; Loop as long as there are registers left:
	dec tmp
	bpl in_f_55_ld_i_v_loop ; Flips to negative when decrementing 0.
	; Increment I register:
	ldab op1
	addb #1
	ldx i
	abx
	stx i
	jmp increment_pc

in_f_33_ld_b_v:
	; Get data from V register:
	ldx #v
	ldab op1
	abx
	ldaa 0,x
	staa tmp
	; Store data in CHIP-8 memory via I register:
	ldx #i
	ldaa 0,x
	adda #CHIP8_MEM_OFFSET
	ldab 1,x
	xgdx
	; Divide by 100:
	ldab tmp
	ldaa #100
	jsr divide
	stab 0,x
	; Modulus 100:
	ldab tmp
	ldaa #100
	jsr divide
	; Divide by 10:
	tab
	ldaa #10
	jsr divide
	stab 1,x
	; Modulus 10:
	ldab tmp
	ldaa #10
	jsr divide
	staa 2,x
	jmp increment_pc

in_f_29_ld_f_v:
	ldx #v
	ldab op1
	abx
	ldab 0,x
	ldx #0
	andb #$0F
	beq in_f_29_ld_f_v_no_loop
in_f_29_ld_f_v_loop:
	inx
	inx
	inx
	inx
	inx
	decb
	bne in_f_29_ld_f_v_loop
in_f_29_ld_f_v_no_loop:
	xgdx
	std i
	jmp increment_pc

in_f_1e_add_i_v:
	ldx #v
	ldab op1
	abx
	ldab 0,x
	ldx i
	abx
	stx i
	jmp increment_pc

in_f_18_ld_st_v:
	ldx #v
	ldab op1
	abx
	ldaa 0,x
	staa st
	jmp increment_pc

in_f_15_ld_dt_v:
	ldx #v
	ldab op1
	abx
	ldaa 0,x
	staa dt
	jmp increment_pc

in_f_0a_ld_v_k:
	ldab #15
in_f_0a_ld_v_k_scan:
	pshb
	jsr is_key_pressed
	pulb
	tsta
	beq in_f_0a_ld_v_k_wait
	decb
	bpl in_f_0a_ld_v_k_scan
	jmp fetch ; Re-run complete instruction to decrement timers!
in_f_0a_ld_v_k_wait:
	pshb
	jsr is_key_pressed
	pulb
	tsta
	; Wait for key to be released again as well:
	beq in_f_0a_ld_v_k_wait
	tba
	ldx #v
	ldab op1
	abx
	staa 0,x
	jmp increment_pc

in_f_07_ld_v_dt:
	ldx #v
	ldab op1
	abx
	ldaa dt
	staa 0,x
	jmp increment_pc

increment_pc:
	ldd pc
	addd #2
	std pc
	; Loop to next instruction:
	jmp fetch

panic:
	dc.b 0 ; Activate HX-20 trap with undefined opcode.
	jmp increment_pc

clear_screen:
        ; Clear the physical screen:
	ldab #0
	jsr DSPLCN
	; Clear the screen mirror:
	ldx #screen
	clrb
clear_screen_loop:
	clr 0,x
	inx
	incb
	bne clear_screen_loop
	rts

; Based on 8-bit binary division routine from:
; https://www.inf.pucrs.br/calazans/undergrad/orgcomp_EC/mat_microproc/MC6800-AssemblyLProg.pdf
divide:
	; Dividend in B prior to call.
	; Divisor in A prior to call.
	pshx
	ldx #8
	staa tmp2
	clra
divide_loop:
	aslb
	rola
	cmpa tmp2
	bcs divide_check_counter
	suba tmp2
	incb
divide_check_counter:
	dex
	bne divide_loop
	; Quotient in B after call.
	; Remainder in A after call.
	pulx
	rts

; Key mapping:
; +-----------------+-----------------+-----------------+-----------------+
; | 1='1' 0x01 0:02 | 2='2' 0x02 0:04 | 3='3' 0x03 0:08 | C='4' 0x04 0:10 |
; | 4='Q' 0x21 4:02 | 5='W' 0x27 4:80 | 6='E' 0x15 2:20 | D='R' 0x22 4:04 |
; | 7='A' 0x07 2:02 | 8='S' 0x23 4:08 | 9='D' 0x14 2:10 | E='F' 0x15 2:40 |
; | A='Z' 0x2A 5:04 | 0='X' 0x28 5:01 | B='C' 0x13 2:08 | F='V' 0x26 4:40 |
; +-----------------+-----------------+-----------------+-----------------+
;              0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  A,  B,  C,  D,  E,  F
key_row dc.b   5,  0,  0,  0,  4,  4,  2,  2,  4,  2,  5,  2,  0,  4,  2,  4
key_bit dc.b $01,$02,$04,$08,$02,$80,$20,$02,$08,$10,$04,$08,$10,$04,$40,$40

is_key_pressed:
	; Key to check in B prior to call.
	ldx #key_bit
	abx
	ldaa 0,x
	staa tmp ; Store the mapped key bit.
	ldx #key_row
	abx
	ldaa 0,x
	psha ; Push the mapped key row.
	jsr KEYSCN
	ldx #NEWKTB
	pulb
	abx ; Pull and add the mapped key row.
	ldaa 0,x ; Load row from key scan table.
	bita tmp ; Check if key bit matches.
	bne is_key_pressed_not
	ldaa #$ff ; Return key PRESSED flag in A.
	rts
is_key_pressed_not:
	ldaa #0 ; Return key NOT pressed flag in A.
	rts

; Built-in font sprite data:
font_0	dc.b $F0,$90,$90,$90,$F0
font_1	dc.b $20,$60,$20,$20,$70
font_2	dc.b $F0,$10,$F0,$80,$F0
font_3	dc.b $F0,$10,$F0,$10,$F0
font_4	dc.b $90,$90,$F0,$10,$10
font_5	dc.b $F0,$80,$F0,$10,$F0
font_6	dc.b $F0,$80,$F0,$90,$F0
font_7	dc.b $F0,$10,$20,$40,$40
font_8	dc.b $F0,$90,$F0,$90,$F0
font_9	dc.b $F0,$90,$F0,$10,$F0
font_a	dc.b $F0,$90,$F0,$90,$90
font_b	dc.b $E0,$90,$E0,$90,$E0
font_c	dc.b $F0,$80,$80,$80,$F0
font_d	dc.b $E0,$90,$90,$90,$E0
font_e	dc.b $F0,$80,$F0,$80,$F0
font_f	dc.b $F0,$80,$F0,$80,$80

; Variables:
op1	dc.b 0 ; First Opcode Byte (First nibble filtered!)
op2	dc.b 0 ; Second Opcode Byte
pc	dc.w 0 ; Program Counter
i	dc.w 0 ; Index Register
sp	dc.b 0 ; Stack Pointer
dt	dc.b 0 ; Delay Timer
st	dc.b 0 ; Sound Timer
timer	dc.b 0 ; Last Timer Value
v	dc.b 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; Registers
vf	dc.b 0 ; Flag Register
stack	dc.w 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0 ; Stack
tmp	dc.b 0 ; Temp Variable
tmp2	dc.b 0 ; Temp Variable 2
drw_y	dc.b 0 ; Draw Position Y
drw_x	dc.b 0 ; Draw Position X
drw_i	dc.b 0 ; Draw Memory (Column) Index
drw_j	dc.b 0 ; Draw Row Index
drw_d	dc.b 0 ; Draw Row Pixel Data
drw_c	dc.b 0 ; Draw Collision
screen	ds 256 ; Screen Mirror

