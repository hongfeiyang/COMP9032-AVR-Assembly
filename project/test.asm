.include "m2560def.inc"

.include "lcd_defs.asm"
.include "keypad_defs.asm"
.include "lcd_macros.asm"

.equ MAP_SIZE       =   16
.def CURR_ROL       =   r2
.def CURR_COL       =   r3
.dseg
.org 0x200
    KEY:    .byte 1

.cseg
.org 0x0000
	jmp RESET

    map:    .db     1,  2,  3,  4,  5,  6,  7,  8,  9,  8,  7,  6,  5,  4,  3,  0   ; ROW 0
            .db     2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  1   ; ROW 1
            .db     3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  2   ; ROW 2
            .db     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  3   ; ROW 3
            .db     5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  4   ; ROW 4
            .db     6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  5   ; ROW 5
            .db     7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  6   ; ROW 6
            .db     8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  7   ; ROW 7
            .db     9,  9,  9,  9,  9,  9,  9,  9,  9,  9,  9,  9,  9,  9,  9,  8   ; ROW 8
            .db     8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  8,  9   ; ROW 9
            .db     7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  7,  8   ; ROW 10
            .db     6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  7   ; ROW 11
            .db     5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  5,  6   ; ROW 12
            .db     4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  4,  5   ; ROW 13
            .db     3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  4   ; ROW 14
            .db     2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  3   ; ROW 15

RESET:
	ldi r16, low(RAMEND)
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16

	ldi r16, PORTLDIR			; columns are outputs, rows are inputs
	sts	DDRL, r16				; keypad

    ser r16
    out DDRC, r16

    M_LCD_INIT
    ldi r17, 0

main:
    ; rcall wait_for_key_input
    ; inc r17
    ; out PORTC, r17
    ; sleep_200msKEY

    ; M_DO_LCD_DATA r0

    ; rcall test

    ; rcall display_grid

    ldi r16, 14
    mov CURR_ROL, r16
    ldi r16, 0
    mov CURR_COL, r16
    rcall print_curr_row
    rcall print_curr_col
    rcall sleep_200ms


    inc r17
    out PORTC, r17
    rcall sleep_200ms

    rjmp main



print_curr_row:
    push ZH
    push ZL
    push r16
    push r17
    push r18

    ldi r17, MAP_SIZE
    mul CURR_ROL, r17           ; rol * MAP_SIZE gives the offset of the start of this rol in the map array, result is in r1:r0

    ldi ZH, high(map<<1)
    ldi ZL, low(map<<1)

    clr r18
    add ZL, r0                  ; ajust Z pointer to point at the first element of the current row
    adc ZH, r1                  ; only data in r0 is important, and r1 is zero, becuase map size is 16 and 16 * 16 = 256, which is just enought to fill up r0, also CURR_ROL < 16

print_row_loop:
    lpm r16, Z+
    subi r16, -'0'
    M_DO_LCD_DATA r16
    inc r18
    cpi r18, MAP_SIZE
    breq end_print_row_loop
    rjmp print_row_loop
end_print_row_loop:
    pop r18
    pop r17
    pop r16
    pop ZL
    pop ZH
    ret



print_curr_col:
    push ZH
    push ZL
    push r16
    push r17
    push r18
    push r19

    ldi ZH, high(map<<1)
    ldi ZL, low(map<<1)

    ldi r17, MAP_SIZE
    clr r19                         ; temp register just to hold a zero
    clr r18                         ; number of iterations

    add ZL, CURR_COL                ; add column offset to Z pointer, so Z is pointing to the correct column
    adc ZH, r18

print_col_loop:
    lpm r16, Z
    add ZL, r17                     ; manually increment Z pointer by MAP_SIZE, which is to point to the same column in the next row
    adc ZH, r19
    subi r16, -'0'
    M_DO_LCD_DATA r16
    inc r18
    cpi r18, MAP_SIZE
    breq end_print_col_loop
    rjmp print_col_loop
end_print_col_loop:

    pop r19
    pop r18
    pop r17
    pop r16
    pop ZL
    pop ZH
    ret 

display_tile:
    push ZH
    push ZL
    push r16
    push r0
    push r1
    push r18
    push r19

    ldi r19, 0
    ldi r18, MAP_SIZE
    mul CURR_ROL, r18
    add r0, CURR_COL
    adc r1, r19
    

    ldi ZH, high(map<<1)
    ldi ZL, low(map<<1)

    add ZL, r0
    adc ZH, r1

    lpm r16, Z
    subi r16, -'0'
    M_DO_LCD_DATA r16

    pop r19
    pop r18
    pop r1
    pop r0
    pop r16
    pop ZL
    pop ZH
    ret




; --------------------------------------------------------------------------------------------------------------- ;
; ------------------------------------------------------- Subroutines ------------------------------------------- ;
; --------------------------------------------------------------------------------------------------------------- ;

; Binary number to display stored in r16
display_decimal:
	push r18
	in r18, SREG
	push r18
	push r16 				; hold binary number to be converted and displayed
    push r19 				; hold number of iterations
    push r17 				; hold temporary value
    push r24				; hold lower two digits of 8 bit BCD formatted number
    push r25 				; hold upper two digits of 8 bit BCD formatted number (8 bits can only have 1 upper digit)

    ; Using the double dabble algorithm
    ; https://en.wikipedia.org/wiki/Double_dabble
    ; Convert to packed BCD format
	; For example, 5 becomes 0101, 10 becomes 0001 0000

    clr r24
    clr r25
    ldi r19, 8		; number of iterations, since we have 8 bits to convert

double_dabble_loop:
    lsl r16
    rol r24
    rol r25

    dec r19
    tst r19
    breq end_double_dabble

check_ones:
    mov r17, r24
    andi r17, 0b00001111
    cpi r17, 5
    brlo check_tens
    subi r24, -3
check_tens:
	mov r17, r24
	swap r17
	andi r17, 0b00001111
	cpi r17, 5
	brlo double_dabble_loop
	subi r24, -3<<4
	rjmp double_dabble_loop
end_double_dabble:

	; Display the BCD

	clear_lcd

	; Display the hundreds
    andi r25, 0b00001111
    subi r25, -'0'
    ; do_lcd_data r25

	; Display the tens
    mov r17, r24
    swap r17
    andi r17, 0b00001111
    subi r17, -'0'
    ; do_lcd_data r17

	; Display the ones
    andi r24, 0b00001111
    subi r24, -'0'
    ; do_lcd_data r24

    pop r25
	pop r24
    pop r17
    pop r19
	pop r16
	pop r18
	out SREG, r18
	pop r18
	ret

.include "lcd_functions.asm"
.include "keypad_functions.asm"
.include "led_bar_functions.asm"