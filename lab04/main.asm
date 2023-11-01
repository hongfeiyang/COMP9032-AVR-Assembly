.include "m2560def.inc" 
 

    .equ LCD_RS         =   7
    .equ LCD_E          =   6
    .equ LCD_RW         =   5
    .equ LCD_BE         =   4

    .macro lcd_set
        sbi PORTA, @0
    .endmacro

    .macro lcd_clr
        cbi PORTA, @0
    .endmacro

    .macro do_lcd_command
        push r16
        ldi r16, @0
        rcall lcd_command
        rcall lcd_wait
        pop r16
    .endmacro

    .macro do_lcd_data
        push r16
        mov r16, @0
        rcall lcd_data
        rcall lcd_wait
        pop r16
    .endmacro


    ; LCD set up and initialization
	ser r16
	out DDRF, r16
	out DDRA, r16
	clr r16
	out PORTF, r16
	out PORTA, r16

	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink

main:
    ldi r16, 243
    rcall display_decimal
end:
    rjmp end


; Display data stored in 
display_decimal:

	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00001110
    
    .def TEMP = r20

	push r16
    push r19
    push r20
    push r24
    push r25


    ; Using the double dabble algorithm
    ; https://en.wikipedia.org/wiki/Double_dabble

    ; Convert to BCD
    clr r24
    clr r25
    ldi r19, 8

double_dabble_loop:
    lsl r16
    rol r24
    rol r25

    mov TEMP, r24
    andi TEMP, 0b00001111
    cpi TEMP, 5
    brlo skip_add
    subi r24, -3
skip_add:
    dec r19
    tst r19
    brne double_dabble_loop

    ; Display 

    andi r25, 0b00001111
    subi r25, -'0'
    do_lcd_data r25

    mov TEMP, r24
    swap TEMP
    andi TEMP, 0b00001111
    subi TEMP, -'0'
    do_lcd_data TEMP

    andi r24, 0b00001111
    subi r24, -'0'
    do_lcd_data r24

    pop r25
	pop r24
    pop r20
    pop r19
	pop r16
    .undef TEMP
	ret

;funcions
lcd_command:
	out PORTF, r16
	nop
	lcd_set LCD_E
	nop
	nop
	nop
	lcd_clr LCD_E
	nop
	nop
	nop
	ret

lcd_data:
	out PORTF, r16
	lcd_set LCD_RS
	nop
	nop
	nop
	lcd_set LCD_E
	nop
	nop
	nop
	lcd_clr LCD_E
	nop
	nop
	nop
	lcd_clr LCD_RS
	ret

lcd_wait:
	push r16
	clr r16
	out DDRF, r16
	out PORTF, r16
	lcd_set LCD_RW
lcd_wait_loop:
	nop
	lcd_set LCD_E
	nop
	nop
    nop
	in r16, PINF
	lcd_clr LCD_E
	sbrc r16, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r16
	out DDRF, r16
	pop r16
	ret

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret

sleep_50ms:
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	ret

sleep_200ms:
	rcall sleep_50ms
	rcall sleep_50ms
	rcall sleep_50ms
	rcall sleep_50ms
	ret
