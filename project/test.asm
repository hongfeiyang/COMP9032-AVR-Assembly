.include "m2560def.inc"

.include "lcd_defs.asm"
.include "keypad_defs.asm"

.include "lcd_macros.asm"

.macro Clear
    push r16
	ldi YL, low(@0)              ; load the memory address to Y
	ldi YH, high(@0)
	clr r16
	st Y+, r16                ; clear the two bytes at @0 in SRAM
	st Y, r16
    pop r16
.endmacro

;to help compute and store the keypad input numbers that are multiple digits 
.macro M_MULT_TEN
    push r16
    ldi r16, 10
    mul @0, r16
    mov @0, r0
    pop r16
.endmacro


.equ MAP_SIZE       =   16
.def DroneX         =   r4
.def DroneY         =   r5
.def DroneZ         =   r6
.def Direction      =   r7    ; N: North, S: South, E: East, W: West, U: Up, D: Down
.def Spd            =   r8
.def FlightState    =   r9    ; F: Flight, H: Hover, R: Return, C: Crash
.def AccidentX      =   r10
.def AccidentY      =   r11

.dseg
.org 0x200
    SecondCounter:  	.byte 2                     ; Two - byte counter for counting the number of seconds. Consider this as a clock that counts the number of seconds has elapsed.
    TempCounter:    	.byte 2						; Two - byte counter for counting the number of intervals of 1024 us. Will reset to 0 after 1000 intervals.

.cseg
.org 0x0000
	jmp RESET                   ; Reset interrupt vector 
.org OVF0addr
	jmp Timer0OVF               ; Timer0 overflow interrupt vector

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

opening_line:   .db     "Acci loc: "

RESET:
	ldi r16, low(RAMEND)
	out SPL, r16
	ldi r16, high(RAMEND)
	out SPH, r16

	ldi r16, PORTLDIR			; columns are outputs, rows are inputs
	sts	DDRL, r16				; set up keypad

    ser r16                     ; Set up LED bar to be output pins
    out DDRC, r16

    clr AccidentX
    clr AccidentY
    clr DroneX
    clr DroneY
    clr DroneZ
    ldi r16, 'E'
    mov Direction, r16
    ldi r16, 1
    mov Spd, r16
    ldi r16, 'F'
    mov FlightState, r16

    M_LCD_INIT
    
    M_CLEAR_LCD
    M_DO_LCD_COMMAND 0x40 | (1<<7)      ; Set DDRAM address to 0x40 (second line) 40 ~ 67 are the second line, 00 ~ 27 are the first line, DB7 must be 1

    rcall print_opening_line
    rcall read_accident_location
    
    ; Start game, enable timer interrupt

    ; Timer0 interrupt set up and initialization
	ldi r16, 0b00000000
	out TCCR0A, r16
	ldi r16, 0b00000011
	out TCCR0B, r16          	; Prescaler value=64, counting 1024 us
	ldi r16, 1<<TOIE0
	sts TIMSK0, r16           	; T / C0 interrupt enable

    sei

    jmp main_loop


print_opening_line:
    push ZH
    push ZL
    push r17
    push r16

    ldi ZH, high(opening_line<<1)
    ldi ZL, low(opening_line<<1)

    clr r17
print_opening_line_loop:
    lpm r16, Z+
    M_DO_LCD_DATA r16
    inc r17
    cpi r17, 10 ; 10 characters to be printed
    brne print_opening_line_loop
    
    pop r16
    pop r17
    pop ZL
    pop ZH
    ret



read_accident_location:
    push r18

get_x_corrdinate:
    rcall wait_for_key_input
    rcall sleep_200ms
    rcall sleep_200ms
    M_DO_LCD_DATA r0
    mov r18, r0
    cpi r18, '*'
    breq get_y_corrdinate
    M_MULT_TEN AccidentX
    subi r18, '0'
    add AccidentX, r18
    out PORTC, AccidentX
    rjmp get_x_corrdinate
get_y_corrdinate:
    rcall wait_for_key_input
    rcall sleep_200ms
    rcall sleep_200ms
    M_DO_LCD_DATA r0
    mov r18, r0
    cpi r18, '*'
    breq end_set_up_accident_location
    M_MULT_TEN AccidentY
    subi r18, '0'
    add AccidentY, r18
    out PORTC, AccidentY
    rjmp get_y_corrdinate

end_set_up_accident_location:
    pop r18
    ret

; --------------------------------------------------------------------------------------------------------------- ;
; ------------------------------------------------------- Timer0 Overflow Handler ------------------------------- ;
; --------------------------------------------------------------------------------------------------------------- ;
Timer0OVF:                      ; interrupt subroutine for Timer0
	push r16
    in r16, SREG
	push r16                    ; Prologue starts.
	push YH                     ; Save all conflict registers in the prologue.
	push YL
	push r25
	push r24                    ; Prologue ends.

	ldi YL, low(TempCounter)    ; Load the address of the temporary
	ldi YH, high(TempCounter)   ; counter.
	ld r24, Y+                  ; Load the value of the temporary counter.
	ld r25, Y
    adiw r25:r24, 1             ; Increase the temporary counter by one
	
	cpi r24, low(500)          ; Check if (r25:r24)=500
	brne NotSecond
	cpi r25, high(500)
	brne NotSecond
	
    ;; Otherwise we have reached 1000ms
    ;; Do something here
    M_CLEAR_LCD
    rcall lcd_wait_busy
    rcall print_curr_path
    rcall print_status_bar

	Clear TempCounter           ; Reset the temporary counter.
	ldi YL, low(SecondCounter)  ; Load the address of the second
	ldi YH, high(SecondCounter) ; counter.
	ld r24, Y +                 ; Load the value of the second counter.
	ld r25, Y
    adiw r25:r24, 1             ; Increase the second counter by one.

    out PORTC, r24              ; Display the second counter on the LED bar.

	st Y, r25                   ; Store the value of the second counter.
	st - Y, r24
	rjmp endif
NotSecond:
	st Y, r25                  	; Store the value of the temporary counter.
	st - Y, r24
endif:
	pop r24                     ; Epilogue starts;
	pop r25                     ; Restore all conflict registers from the stack.
	pop YL
	pop YH
	pop r16
	out SREG, r16
	pop r16                    	; Epilogue ends.
	reti


main_loop:
    push r16
    rcall wait_for_key_input
    mov r16, r0
    cpi r16, '2'
    breq north
    cpi r16, '4'
    breq west
    cpi r16, '6'
    breq east
    cpi r16, '8'
    breq south
    rjmp end_main_loop
north:
    ldi r16, 'N'
    rjmp end_main_loop
south:
    ldi r16, 'S'
    rjmp end_main_loop
east:
    ldi r16, 'E'
    rjmp end_main_loop
west:
    ldi r16, 'W'
    rjmp end_main_loop
end_main_loop:
    mov Direction, r16
    pop r16
    rjmp main_loop



print_curr_path:
    push r16

    M_DO_LCD_COMMAND 0x00 | (1<<7)

    ldi r16, 'N'
    cp Direction, r16
    breq vertical
    ldi r16, 'S'
    cp Direction, r16
    breq vertical
    ldi r16, 'E'
    cp Direction, r16
    breq horizontal
    ldi r16, 'W'
    cp Direction, r16
    breq horizontal
    rjmp end_print_curr_path
horizontal:
    rcall print_curr_row
    rjmp end_print_curr_path
vertical:
    rcall print_curr_col
    rjmp  end_print_curr_path
end_print_curr_path:
    pop r16
    ret

print_status_bar:
    push r16

    M_DO_LCD_COMMAND 0x40 | (1<<7)

    M_DO_LCD_DATA FlightState
    ldi r16, ' '
    M_DO_LCD_DATA r16
    ldi r16, '('
    M_DO_LCD_DATA r16
    mov r16, DroneX
    subi r16, -'0'
    M_DO_LCD_DATA r16
    ldi r16, ','
    M_DO_LCD_DATA r16
    mov r16, DroneY
    subi r16, -'0'
    M_DO_LCD_DATA r16
    ldi r16, ','
    M_DO_LCD_DATA r16
    mov r16, DroneZ
    subi r16, -'0'
    M_DO_LCD_DATA r16
    ldi r16, ')'
    M_DO_LCD_DATA r16
    ldi r16, ' '
    M_DO_LCD_DATA r16
    mov r16, Spd
    subi r16, -'0'
    M_DO_LCD_DATA r16
    ldi r16, '/'
    M_DO_LCD_DATA r16
    M_DO_LCD_DATA Direction
    pop r16
    ret


print_curr_row:
    push ZH
    push ZL
    push r16
    push r17
    push r18

    ldi r17, MAP_SIZE
    mul DroneY, r17           ; rol * MAP_SIZE gives the offset of the start of this rol in the map array, result is in r1:r0

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

    add ZL, DroneX                ; add column offset to Z pointer, so Z is pointing to the correct column
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
    mul DroneY, r18
    add r0, DroneX
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

	M_CLEAR_LCD

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
